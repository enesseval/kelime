import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

/// Everything Bugün shows, read in one go.
struct TodayData: Sendable {
    var hero: WordItem?
    var strugglingCount: Int
    var stats: WeekStats
    /// "YDS'ye 42 gün", when the user set an exam date in Ayarlar.
    var examCountdown: String?
    /// What the widget draws from, e.g. "B1 kursu · YDS".
    var widgetSources: String
    var bannerDismissed: Bool
    var level: CEFRLevel
    var puzzle: DailyPuzzleInfo?
    var course: CourseState?
    var examPlan: ExamPlanStatus?

    static func load(db: Database, clock: AppClock) throws -> TodayData {
        let prefs = try Preferences.load(db)
        var heroID = try WidgetQueue.current(db: db, clock: clock)?.cardID
        if heroID == nil {
            heroID = try CardQueries.candidates(in: prefs.entitledDecks, db: db).first?.cardID
        }
        let stats = try StatsQueries.week(db: db, clock: clock)
        let exam = try ExamCountdown.daysLeft(db: db, clock: clock)
        let courses = try Curriculum.levels(db: db)
        let lists = try UserLists.summaries(db: db).filter { $0.list.enabled && $0.total > 0 }.map(\.list.title)
        let decks = prefs.enabledDecks.isEmpty && !lists.isEmpty ? [] : prefs.entitledDecks
        let sources = decks.map { deck in
            deck.level.map { courses.contains($0) ? "\($0.rawValue) kursu" : $0.rawValue } ?? deck.rawValue
        } + lists
        return TodayData(
            hero: try heroID.flatMap { try WordQueries.item(id: $0, db: db) },
            strugglingCount: stats.strugglingNow,
            stats: stats,
            examCountdown: exam.map { "\($0.exam.rawValue)\($0.exam == .yds ? "'ye" : "'e") \($0.days) gün" },
            widgetSources: sources.joined(separator: " · "),
            bannerDismissed: try Settings.bool(.widgetBannerDismissed, in: db),
            level: prefs.level,
            puzzle: try DailyPuzzleInfo.load(db: db, clock: clock),
            course: try Curriculum.state(db: db),
            examPlan: try ExamPlan.status(db: db, clock: clock)
        )
    }
}

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var data: TodayData?
    @State private var widgetInstalled = true
    @State private var showGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let data {
                    if !widgetInstalled && !data.bannerDismissed {
                        widgetBanner
                    }
                    if let hero = data.hero {
                        Button { model.router.openWord(hero.id) } label: { HeroCard(item: hero) }
                            .buttonStyle(.plain)
                    }
                    Button { model.router.openLists() } label: {
                        HStack(spacing: 6) {
                            (Text("Widget'ında: ").foregroundStyle(Palette.ink2) + Text(data.widgetSources).foregroundStyle(Palette.ink).fontWeight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 8)
                            Text("Değiştir").foregroundStyle(Palette.accent).fontWeight(.semibold)
                        }
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .padding(.horizontal, 4)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Widget'ında \(data.widgetSources). Listeleri değiştir")
                    if let course = data.course {
                        CurrentUnitCard(course: course)
                    }
                    if let plan = data.examPlan {
                        ExamPlanCard(plan: plan)
                    }
                    QuickReviewCard(strugglingCount: data.strugglingCount)
                    PuzzleCard(level: data.level, info: data.puzzle)
                    WeekStatsRow(stats: data.stats)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .hiddenNavigationBar()
        .task(id: model.dataVersion) {
            let clock = model.clock
            data = await model.read { db in try TodayData.load(db: db, clock: clock) }
            widgetInstalled = await Self.hasInstalledWidget()
            if widgetInstalled && !UserDefaults.standard.bool(forKey: "usage.widgetSeen") {
                UserDefaults.standard.set(true, forKey: "usage.widgetSeen")
                UsageCounter.count(.widgetInstalled)
            }
        }
        .sheet(isPresented: $showGuide) { WidgetGuideView() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            ScreenTitle(title: "Bugün", kicker: TurkishDate.header(model.clock.now))
            Spacer()
            if let countdown = data?.examCountdown {
                Text(countdown)
                    .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(Palette.ink2)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 11)
                    .overlay(Capsule().strokeBorder(Palette.line))
                    .padding(.bottom, 4)
            }
        }
    }

    private var widgetBanner: some View {
        HStack(spacing: 12) {
            Button { showGuide = true } label: {
                (Text("Widget'ı henüz eklemedin.").fontWeight(.semibold) + Text(" 30 saniye sürer."))
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                Task { await model.dismissWidgetBanner() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(.leading, 16)
        .padding(6)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Whether any Kelime widget is on the lock or home screen.
    static func hasInstalledWidget() async -> Bool {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                let configurations = (try? result.get()) ?? []
                continuation.resume(returning: !configurations.isEmpty)
            }
        }
    }
}

/// "ŞU AN WIDGET'INDA": the current widget card, large.
struct HeroCard: View {
    let item: WordItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ŞU AN WIDGET'INDA")
                    .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                    .tracking(0.9)
                    .foregroundStyle(Palette.ink2)
                Spacer()
                LevelChip(item.card.level)
                StateDot(item.state, size: 10)
            }
            Text(item.card.word)
                .font(KelimeFont.english(58, relativeTo: .largeTitle))
                .tracking(-1.4)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            (Text(item.card.pos.abbreviation).font(KelimeFont.english(17, relativeTo: .body, italic: true)).foregroundStyle(Palette.ink2)
                + Text("  ") + Text(item.card.meaning).font(KelimeFont.ui(17, relativeTo: .body)))
            Rectangle().fill(Palette.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.card.exampleEN).font(KelimeFont.english(19, relativeTo: .body, italic: true))
                Text(item.card.exampleTR).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
            }
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 26, padding: 21)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Kelime detayını açar")
    }
}

/// Bugün's exam plan (Pro): today's share of the exam list until the exam day. Free users see
/// the card with a Pro badge; tapping it explains Pro.
struct ExamPlanCard: View {
    @Environment(AppModel.self) private var model
    let plan: ExamPlanStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("SINAV PLANI · \(plan.exam.rawValue)")
                    .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                    .tracking(0.9)
                    .foregroundStyle(Palette.ink2)
                Spacer()
                if model.isPro {
                    Text("\(plan.daysLeft) gün").font(KelimeFont.ui(12, weight: .semibold)).foregroundStyle(Palette.accent)
                } else {
                    ProBadge()
                }
            }
            if plan.remaining == 0 {
                Text("Listedeki bütün kelimeleri öğrendin 🎉").font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
            } else {
                (Text("Bugün ").foregroundStyle(Palette.ink2)
                    + Text("\(min(plan.doneToday, plan.dailyTarget)) / \(plan.dailyTarget) kelime").fontWeight(.semibold)
                    + Text(" · kalan \(plan.remaining)").foregroundStyle(Palette.ink2))
                    .font(KelimeFont.ui(16, relativeTo: .body))
                ThinProgressBar(fraction: model.isPro ? plan.fraction : 0.35, color: Palette.green)
                    .blur(radius: model.isPro ? 0 : 2)
                HStack(spacing: 10) {
                    Button("Sınav tekrarı") {
                        if model.isPro { Task { model.router.startQuickReview(deck: plan.exam) } } else { model.router.showPaywall(.examPlan) }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 44))
                    if model.isPro && !plan.listOnWidget {
                        Button("Widget'a ekle") { Task { await model.setDeck(plan.exam, enabled: true) } }
                            .buttonStyle(OutlineButtonStyle())
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard()
        .contentShape(Rectangle())
        .onTapGesture { if !model.isPro { model.router.showPaywall(.examPlan) } }
    }
}

struct QuickReviewCard: View {
    @Environment(AppModel.self) private var model
    let strugglingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hızlı Tekrar").font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                Spacer()
                Text("10 kelime").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            }
            Group {
                if strugglingCount > 0 {
                    Text("\(strugglingCount) zorlandığın kelime").foregroundStyle(Palette.amberInk).fontWeight(.semibold)
                        + Text(" seni bekliyor").foregroundStyle(Palette.ink2)
                } else {
                    Text("Yeni kelimelerle kısa bir tur").foregroundStyle(Palette.ink2)
                }
            }
            .font(KelimeFont.ui(15, relativeTo: .subheadline))
            Button("Başla · 2 dk") { Task { await model.startQuickReview() } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .surfaceCard()
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

struct PuzzleCard: View {
    @Environment(AppModel.self) private var model
    let level: CEFRLevel
    let info: DailyPuzzleInfo?

    var body: some View {
        HStack(spacing: 16) {
            PuzzleThumbnail(cell: 7, gap: 1.5, cells: info?.thumbnail ?? PuzzleThumbnail.sample)
            VStack(alignment: .leading, spacing: 8) {
                Text("Günün Bulmacası").font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                Text("\(info?.solved ?? 0)/\(info?.total ?? 5) kelime · \((info?.level ?? level).rawValue)")
                    .font(KelimeFont.ui(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
                ThinProgressBar(fraction: info.map { Double($0.solved) / Double(max($0.total, 1)) } ?? 0)
                Button(info?.completed == true ? "Sonucu gör" : (info?.solved ?? 0) > 0 ? "Devam et" : "Başla") { model.router.openPuzzle() }
                    .buttonStyle(TintedButtonStyle(fullWidth: false))
                    .padding(.top, 4)
            }
        }
        .surfaceCard(padding: 16)
    }
}

/// 8 × 10 crossword thumbnail; letter cells are tinted, solved words green.
struct PuzzleThumbnail: View {
    var cell: CGFloat
    var gap: CGFloat
    /// Letter cells and whether they are solved. Defaults to the design's sample grid.
    var cells: [Int: Bool] = PuzzleThumbnail.sample

    static let sample: [Int: Bool] = {
        var cells: [Int: Bool] = [:]
        func word(_ r: Int, _ c: Int, _ length: Int, across: Bool) {
            for i in 0..<length { cells[(across ? r : r + i) * 8 + (across ? c + i : c)] = false }
        }
        word(0, 2, 6, across: true); word(0, 3, 7, across: false); word(3, 0, 8, across: true)
        word(3, 5, 7, across: false); word(9, 1, 7, across: true)
        return cells
    }()

    var body: some View {
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            ForEach(0..<10, id: \.self) { row in
                GridRow {
                    ForEach(0..<8, id: \.self) { col in
                        RoundedRectangle(cornerRadius: cell * 0.22)
                            .fill(color(cells[row * 8 + col]))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func color(_ solved: Bool?) -> Color {
        switch solved {
        case nil: .clear
        case false?: Palette.surface2
        case true?: Palette.green
        }
    }
}

struct WeekStatsRow: View {
    let stats: WeekStats

    var body: some View {
        ProportionalHStack(weights: [1, 1, 1.4], spacing: 1) {
            stat("\(stats.learnedThisWeek)", "öğrenildi", color: Palette.ink)
            stat("\(stats.strugglingNow)", "zorlanılan", color: Palette.amberInk)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(stats.days, id: \.date) { day in
                        VStack(spacing: 4) {
                            Circle()
                                .strokeBorder(Palette.green, lineWidth: 1.5)
                                .background(Circle().fill(day.reviewed ? Palette.green : .clear))
                                .frame(width: 11, height: 11)
                            Text(day.initial).font(KelimeFont.ui(9, relativeTo: .caption2)).foregroundStyle(Palette.ink2)
                        }
                    }
                }
                Spacer(minLength: 0)
                if stats.streak >= 2 {
                    Text("\(stats.streak) gün üst üste").font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption)).foregroundStyle(Palette.greenInk)
                } else {
                    Text("bu hafta").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Palette.surface)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Bu hafta \(stats.days.filter(\.reviewed).count) gün tekrar" + (stats.streak >= 2 ? ", \(stats.streak) gün üst üste" : "")))
        }
        .background(Palette.line)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line))
    }

    private func stat(_ value: String, _ label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(KelimeFont.ui(24, weight: .semibold, relativeTo: .title2)).foregroundStyle(color)
            Text(label).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.surface)
        .accessibilityElement(children: .combine)
    }
}

/// Lays children side by side with widths proportional to `weights` and a shared height
/// (the tallest child's), like CSS `grid-template-columns: 1fr 1fr 1.4fr`.
struct ProportionalHStack: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat = 0

    private func widths(total: CGFloat, count: Int) -> [CGFloat] {
        let w = (0..<count).map { $0 < weights.count ? weights[$0] : 1 }
        let sum = w.reduce(0, +)
        let available = max(total - spacing * CGFloat(count - 1), 0)
        return w.map { available * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 360
        let ws = widths(total: total, count: subviews.count)
        let height = zip(subviews, ws).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (view, w) in zip(subviews, widths(total: bounds.width, count: subviews.count)) {
            view.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w + spacing
        }
    }
}
