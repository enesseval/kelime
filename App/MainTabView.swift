import KelimeCore
import KelimeUI
import SwiftUI

/// The four tabs, each with its own navigation stack.
struct MainTabView: View {
    @Environment(AppModel.self) private var model

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

            NavigationStack(path: $router.settingsPath) {
                SettingsView().withRoutes()
            }
            .tabItem { Label("Ayarlar", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(Palette.accent)
        .modifier(GlassTabBarBehavior())
        .onOpenURL { url in
            Task { await model.logWidgetOpen(url) }
            router.handle(url)
        }
        .sheet(item: $router.paywall) { request in
            PaywallView(request: request).environment(model)
        }
        .fullScreenCover(isPresented: $router.reviewPresented) {
            QuickReviewView().environment(model)
        }
        .fullScreenCover(item: $router.puzzle) { request in
            CrosswordView(source: request.source).environment(model)
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
            case .unit(let id): UnitView(unitID: id)
            case .story(let unit, let story): StoryView(unitID: unit, storyID: story)
            }
        }
    }
}

/// Oyna hub: Quick Review and today's crossword.
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @State private var puzzle: DailyPuzzleInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Oyna")
                Button { Task { await model.startQuickReview() } } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hızlı Tekrar").font(KelimeFont.english(30, relativeTo: .title))
                        Text("10 kelime · yaklaşık 2 dakika").font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                        HStack {
                            Spacer()
                            Text("Başla")
                                .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(Palette.onAccent)
                                .padding(.horizontal, 18)
                                .frame(minHeight: 44)
                                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.top, 12)
                    }
                    .foregroundStyle(Palette.ink)
                    .surfaceCard(padding: 20)
                }
                .buttonStyle(.plain)

                Button { model.router.openPuzzle() } label: {
                    HStack(spacing: 18) {
                        PuzzleThumbnail(cell: 8, gap: 2, cells: puzzle?.thumbnail ?? PuzzleThumbnail.sample)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Günün Bulmacası").font(KelimeFont.english(30, relativeTo: .title))
                            Text(puzzleSubtitle).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Palette.ink)
                    .surfaceCard(padding: 20)
                }
                .buttonStyle(.plain)
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
            puzzle = await model.read { db in try DailyPuzzleInfo.load(db: db, clock: clock) } ?? nil
        }
    }

    private var puzzleSubtitle: String {
        guard let puzzle else { return "Şu anki bölümünden · ipuçları Türkçe" }
        return puzzle.completed ? "Tamamlandı · yarın yenisi" : "\(puzzle.solved)/\(puzzle.total) kelime · ipuçları Türkçe"
    }
}
