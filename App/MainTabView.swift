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
            .tabItem { Label("Profil", systemImage: "person.crop.circle") }
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
            case .usageCounters: UsageCountersView()
            case .rotation: RotationPickerView()
            case .unit(let id): UnitView(unitID: id)
            case .userList(let id): UserListView(listID: id)
            case .story(let unit, let story): StoryView(unitID: unit, storyID: story)
            case .sharedList(let id): SharedListView(listID: id)
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

                VStack(spacing: 0) {
                Button { model.router.openPuzzle() } label: {
                    HStack(spacing: 18) {
                        PuzzleThumbnail(cell: 8, gap: 2, cells: puzzle?.thumbnail ?? PuzzleThumbnail.sample)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Günün Bulmacası").font(KelimeFont.english(30, relativeTo: .title))
                            Text(puzzleSubtitle).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(Palette.line).frame(height: 1)
                proRow("Arşiv") { model.isPro ? model.router.openArchive() : model.router.showPaywall(.archive) }
                }
                .foregroundStyle(Palette.ink)
                .surfaceCard(padding: 0)

                Button { model.isPro ? model.router.openPersonalPuzzle() : model.router.showPaywall(.personalPuzzle) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sana Özel Bulmaca").font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                            Text("Zorlandığın ve öğrendiğin kelimelerden").font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                        }
                        Spacer()
                        if !model.isPro { ProBadge() } else { Image(systemName: "chevron.right").foregroundStyle(Palette.ink2) }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: model.isPro ? [] : [4, 4])))
                    .contentShape(Rectangle())
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

    private func proRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(KelimeFont.ui(15, relativeTo: .body))
                Spacer()
                if model.isPro {
                    Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                } else {
                    ProBadge()
                }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var puzzleSubtitle: String {
        guard let puzzle else { return "Şu anki bölümünden · ipuçları Türkçe" }
        return puzzle.completed ? "Tamamlandı · yarın yenisi" : "\(puzzle.solved)/\(puzzle.total) kelime · ipuçları Türkçe"
    }
}
