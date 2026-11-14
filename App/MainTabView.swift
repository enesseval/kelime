import KelimeCore
import KelimeUI
import SwiftUI

/// The five tabs, each with its own navigation stack.
struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var importMessage: String?

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        @Bindable var router = model.router
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.todayPath) {
                TodayView().withRoutes()
            }
            .tabItem { Label("Bugün", systemImage: "sun.max") }
            .tag(AppTab.today)

            NavigationStack(path: $router.playPath) {
                PlayView().withRoutes()
            }
            .tabItem { Label("Oyna", systemImage: "square.grid.3x3") }
            .tag(AppTab.play)

            NavigationStack(path: $router.wordsPath) {
                WordsView().withRoutes()
            }
            .tabItem { Label("Kelimelerim", systemImage: "text.book.closed") }
            .tag(AppTab.words)

            NavigationStack(path: $router.discoverPath) {
                DiscoverView().withRoutes()
            }
            .tabItem { Label("Keşfet", systemImage: "safari") }
            .tag(AppTab.discover)

            NavigationStack(path: $router.settingsPath) {
                SettingsView().withRoutes()
            }
            .tabItem { Label("Profil", systemImage: Avatar.tabSymbol(model.account.profile)) }
            .tag(AppTab.settings)
        }
        .tint(Palette.accent)
        .modifier(GlassTabBarBehavior())
        .onOpenURL { url in
            // A shared .kelimelist file opens the list import.
            if url.isFileURL {
                Task { importMessage = await model.importList(from: url) }
                return
            }
            Task { await model.logWidgetOpen(url) }
            router.handle(url)
        }
        .toast($importMessage)
        .sheet(item: $router.paywall) { request in
            WidgetPaywall(request: request).environment(model)
        }
        .sheet(item: $router.trialSummary) { request in
            TrialSummaryView(request: request).environment(model)
        }
        .sheet(item: $router.designPreview) { design in
            PaywallDesignView(design: design, request: AppRouter.PaywallRequest(trigger: .base)).environment(model)
        }
        .fullScreenCover(isPresented: $router.reviewPresented) {
            QuickReviewView().environment(model)
        }
        .fullScreenCover(item: $router.puzzle) { request in
            CrosswordView(source: request.source).environment(model)
        }
        .fullScreenCover(item: $router.game) { game in
            switch game {
            case .wordSearch: WordSearchView().environment(model)
            case .match: MatchView().environment(model)
            }
        }
        .sheet(isPresented: $router.weeklySummaryPresented) {
            WeeklySummaryView().environment(model)
        }
        .sheet(isPresented: $router.reminderAskPresented) {
            ReminderAskSheet().environment(model)
        }
        .onChange(of: router.roundOpen) { _, roundOpen in
            if !roundOpen { Task { await model.presentTrialSummaryIfDue() } }
            // With another sheet up the ask would be refused; it waits for the next round.
            guard !roundOpen, !router.sheetShown, router.reminderAskPending || router.paywallMomentPending else { return }
            // One ask per round: the reminder first; Pro waits for a later good moment.
            let reminder = router.reminderAskPending
            router.reminderAskPending = false
            router.paywallMomentPending = false
            Task {
                // Let the round's cover finish closing first.
                try? await Task.sleep(for: .milliseconds(600))
                guard !router.sheetShown, !router.roundOpen else {
                    // Something opened meanwhile; ask after the next round instead.
                    if reminder { router.reminderAskPending = true } else { router.paywallMomentPending = true }
                    return
                }
                if reminder {
                    router.reminderAskPresented = true
                } else if !model.isPro {
                    router.showPaywall(.moment)
                    Analytics.signal("paywall.moment")
                }
            }
        }
    }

    /// Before iOS 26: the flat bar from the design (page background, hairline, accent for the
    /// selected tab). On iOS 26 and later the system's Liquid Glass bar is used as is.
    private static func configureTabBarAppearance() {
        if #available(iOS 26, *) { return }
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Palette.background)
        appearance.shadowColor = UIColor(Palette.line)
        let normal = UIColor(Palette.ink2)
        let selected = UIColor(Palette.accent)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

/// On iOS 26 the glass tab bar shrinks while scrolling down, leaving more room for content.
private struct GlassTabBarBehavior: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

extension View {
    /// Destinations reachable from any tab.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .word(let id): WordDetailView(cardID: id)
            case .puzzleArchive: PuzzleArchiveView()
            case .widgetMode: WidgetModePickerView()
            case .widgetLog: WidgetLogView()
            case .usageCounters: UsageCountersView()
            case .rotation: RotationPickerView()
            case .unit(let id): UnitView(unitID: id)
            case .userList(let id): UserListView(listID: id)
            case .story(let unit, let story): StoryView(unitID: unit, storyID: story)
            case .sharedList(let id): SharedListView(listID: id)
            case .paywallGallery: PaywallGalleryView()
            case .streak: StreakView()
            }
        }
    }
}

/// What the Oyna cards show next to each game.
struct PlayData: Sendable {
    var puzzle: DailyPuzzleInfo?
    var strugglingCount: Int
    var matchBest: Int
    /// Archive puzzles a free learner can still open this week.
    var archiveRemaining: Int

    static func load(db: Database, clock: AppClock) throws -> PlayData {
        PlayData(
            puzzle: try DailyPuzzleInfo.load(db: db, clock: clock),
            strugglingCount: try StatsQueries.week(db: db, clock: clock).strugglingNow,
            matchBest: try Settings.int(.matchBest, in: db) ?? 0,
            archiveRemaining: try ArchiveQuota.remaining(today: clock.today, db: db)
        )
    }
}

/// Oyna: the four games as equal cards, then the Pro crossword extras.
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @State private var data: PlayData?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Oyna")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    gameCard("Hızlı Tekrar", reviewSubtitle, highlight: (data?.strugglingCount ?? 0) > 0, unlimited: true) {
                        icon("bolt.fill")
                    } action: { Task { await model.startQuickReview() } }
                    gameCard("Günün Bulmacası", puzzleSubtitle) {
                        PuzzleThumbnail(cell: 3.5, gap: 0.6, cells: data?.puzzle?.thumbnail ?? PuzzleThumbnail.sample,
                                        pending: Palette.accent.opacity(0.55))
                            .fixedSize()
                            .frame(width: 44, height: 44)
                            .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } action: { model.router.openPuzzle() }
                    gameCard("Kelime Avı", "Anlamından bul", unlimited: true) {
                        icon("square.grid.3x3.middle.filled")
                    } action: { model.router.openGame(.wordSearch) }
                    gameCard("Eşleştir", (data?.matchBest ?? 0) > 0 ? "60 saniye · en iyi \(data!.matchBest)" : "60 saniye", unlimited: true) {
                        icon("rectangle.2.swap")
                    } action: { model.router.openGame(.match) }
                }

                VStack(spacing: 0) {
                    proRow("Bulmaca arşivi", archiveSubtitle, locked: false) {
                        if model.isPro || (data?.archiveRemaining ?? 1) > 0 {
                            model.router.openArchive()
                        } else {
                            model.router.showPaywall(.archive)
                        }
                    }
                    Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 20)
                    proRow("Sana Özel Bulmaca", "Zorlandığın ve öğrendiğin kelimelerden") {
                        if model.isPro {
                            model.purchases.noteTrialUse(.personalPuzzle)
                            model.router.openPersonalPuzzle()
                        } else {
                            model.router.showPaywall(.personalPuzzle)
                        }
                    }
                }
                .foregroundStyle(Palette.ink)
                .surfaceCard(padding: 0)
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .hiddenNavigationBar()
        .task(id: model.dataVersion) {
            let clock = model.clock
            data = await model.read { db in try PlayData.load(db: db, clock: clock) }
        }
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .frame(width: 44, height: 44)
            .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// One game: the same size for all four, so none looks like an extra.
    private func gameCard(_ title: String, _ subtitle: String, highlight: Bool = false, unlimited: Bool = false,
                          @ViewBuilder art: () -> some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    art().frame(height: 44, alignment: .leading)
                    Spacer(minLength: 4)
                    if unlimited {
                        Text("Sınırsız")
                            .font(KelimeFont.ui(11, weight: .bold, relativeTo: .caption2))
                            .foregroundStyle(Palette.greenInk)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .background(Palette.green.opacity(0.18), in: Capsule())
                    }
                }
                Spacer(minLength: 16)
                Text(title)
                    .font(KelimeFont.english(23, relativeTo: .title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(KelimeFont.ui(13, weight: highlight ? .semibold : .regular, relativeTo: .footnote))
                    .foregroundStyle(highlight ? Palette.amberInk : Palette.ink2)
                    .lineLimit(2, reservesSpace: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .foregroundStyle(Palette.ink)
            .surfaceCard(padding: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var reviewSubtitle: String {
        let count = data?.strugglingCount ?? 0
        return count > 0 ? "\(count) zorlandığın kelime seni bekliyor" : "10 kelime · 2 dakika"
    }

    /// Free learners see how many of the week's two archive puzzles are left.
    private var archiveSubtitle: String {
        guard !model.isPro, let left = data?.archiveRemaining else { return "Geçmiş günlerin bulmacaları" }
        return "Haftada \(ArchiveQuota.freePerWeek) bulmaca · bu hafta \(left) hakkın var"
    }

    /// `locked: false` keeps the row open for everyone (no PRO badge).
    private func proRow(_ title: String, _ subtitle: String, locked: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                    Text(subtitle).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                }
                Spacer()
                if model.isPro || !locked {
                    Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                } else {
                    ProBadge()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var puzzleSubtitle: String {
        guard let puzzle = data?.puzzle else { return "İpuçları Türkçe" }
        return puzzle.completed ? "Tamamlandı · yarın yenisi" : "\(puzzle.solved)/\(puzzle.total) kelime çözüldü"
    }
}
