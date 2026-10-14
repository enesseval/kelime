import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

/// Everything Bugün shows, read in one go.
struct TodayData: Sendable {
    var hero: WordItem?
    var strugglingCount: Int
    var reviewsRemaining: Int?
    var stats: WeekStats
    var examDays: Int?
    var examName: String
    var bannerDismissed: Bool
    var level: CEFRLevel

    static func load(db: Database, clock: AppClock) throws -> TodayData {
        let prefs = try Preferences.load(db)
        var heroID = try WidgetQueue.current(db: db, clock: clock)?.cardID
        if heroID == nil {
            heroID = try CardQueries.candidates(in: prefs.entitledDecks, db: db).first?.cardID
        }
        let stats = try StatsQueries.week(db: db, clock: clock)
        let goal = try Settings.string(.goal, in: db)
        let examDays = goal == "yds" ? StatsQueries.daysUntilExam(try Settings.date(.examDate, in: db), clock: clock) : nil
        return TodayData(
            hero: try heroID.flatMap { try WordQueries.item(id: $0, db: db) },
            strugglingCount: stats.strugglingNow,
            reviewsRemaining: try QuickReviewLimit.remaining(db: db, clock: clock),
            stats: stats,
            examDays: examDays,
            examName: "YDS",
            bannerDismissed: try Settings.bool(.widgetBannerDismissed, in: db),
            level: prefs.level
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
                    QuickReviewCard(strugglingCount: data.strugglingCount, remaining: data.reviewsRemaining)
                    PuzzleCard(level: data.level)
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
        }
        .sheet(isPresented: $showGuide) { WidgetGuideView() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            ScreenTitle(title: "Bugün", kicker: TurkishDate.header(model.clock.now))
            Spacer()
            if let days = data?.examDays, let name = data?.examName {
                Text("\(name)'ye \(days) gün")
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

struct QuickReviewCard: View {
    @Environment(AppModel.self) private var model
    let strugglingCount: Int
    /// nil = unlimited (Pro).
    let remaining: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hızlı Tekrar").font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                Spacer()
                Text("10 kelime").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            }
            if remaining == 0 {
                HStack(spacing: 12) {
                    Text("Yarın tekrar · ya da Pro ile sınırsız")
                        .font(KelimeFont.ui(15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.ink2)
                    Spacer()
                    Button("Pro'ya bak") { model.router.showPaywall(.reviewLimit) }
                        .buttonStyle(OutlineButtonStyle())
                }
            } else {
                Group {
                    if strugglingCount > 0 {
                        Text("\(strugglingCount) zorlandığın kelime").foregroundStyle(Palette.amberInk).fontWeight(.semibold)
                            + Text(" seni bekliyor").foregroundStyle(Palette.ink2)
                    } else {
                        Text("Yeni kelimelerle kısa bir tur").foregroundStyle(Palette.ink2)
                    }
                }
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                Button("Başla · 2 dk") { model.router.startQuickReview() }
                    .buttonStyle(PrimaryButtonStyle())
            }
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

    var body: some View {
        HStack(spacing: 16) {
            PuzzleThumbnail(cell: 7, gap: 1.5)
            VStack(alignment: .leading, spacing: 8) {
                Text("Günün Bulmacası").font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                Text("0/5 kelime · \(level.rawValue)").font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                ThinProgressBar(fraction: 0)
                Button("Devam et") { model.router.openPuzzle() }
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
        HStack(spacing: 1) {
            stat("\(stats.learnedThisWeek)", "öğrenildi", color: Palette.ink)
            stat("\(stats.strugglingNow)", "zorlanılan", color: Palette.amberInk)
            VStack(alignment: .leading) {
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
                Spacer(minLength: 4)
                Text("bu hafta").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .layoutPriority(1.4)
            .background(Palette.surface)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Bu hafta \(stats.days.filter(\.reviewed).count) gün tekrar"))
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.line)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line))
    }

    private func stat(_ value: String, _ label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(KelimeFont.ui(24, weight: .semibold, relativeTo: .title2)).foregroundStyle(color)
            Text(label).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.surface)
        .accessibilityElement(children: .combine)
    }
}
