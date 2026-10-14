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

            NavigationStack {
                SettingsPlaceholderView()
            }
            .tabItem { Label("Ayarlar", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(Palette.accent)
        .onOpenURL { router.handle($0) }
        .sheet(item: $router.paywall) { request in
            PaywallPlaceholderView(request: request)
        }
        .fullScreenCover(isPresented: $router.reviewPresented) {
            QuickReviewView().environment(model)
        }
        .fullScreenCover(item: $router.puzzle) { request in
            CrosswordView(source: request.source).environment(model)
        }
    }

    /// Flat bar from the design: page background, hairline on top, accent for the selected tab.
    private static func configureTabBarAppearance() {
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

extension View {
    /// Destinations reachable from any tab.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .word(let id): WordDetailView(cardID: id)
            case .puzzleArchive: PuzzleArchiveView()
            }
        }
    }
}

/// Oyna hub: Quick Review, today's crossword (milestone 6) and the Pro archive.
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @State private var remaining: Int?
    @State private var puzzle: DailyPuzzleInfo?
    @State private var isPro = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Oyna")
                Button { Task { await model.startQuickReview() } } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hızlı Tekrar").font(KelimeFont.english(30, relativeTo: .title))
                        Text("10 kelime · yaklaşık 2 dakika").font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                        HStack {
                            Text(remainingText)
                                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                                .foregroundStyle(Palette.ink2)
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
                    Button { model.router.openArchive(isPro: isPro) } label: {
                        HStack {
                            Text("Arşiv").font(KelimeFont.ui(15, relativeTo: .body))
                            Spacer()
                            if isPro {
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
                .foregroundStyle(Palette.ink)
                .surfaceCard(padding: 0)

                Button { model.router.openPersonalPuzzle(isPro: isPro) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sana Özel Bulmaca").font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                            Text("Zorlandığın kelimelerle").font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                        }
                        Spacer()
                        if !isPro { ProBadge() }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: isPro ? [] : [4, 4])))
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
            remaining = await model.read { db in try QuickReviewLimit.remaining(db: db, clock: clock) } ?? nil
            puzzle = await model.read { db in try DailyPuzzleInfo.load(db: db, clock: clock) } ?? nil
            isPro = await model.read { db in try Settings.bool(.isPro, in: db) } ?? false
        }
    }

    private var puzzleSubtitle: String {
        guard let puzzle else { return "ipuçları Türkçe" }
        return puzzle.completed ? "Tamamlandı · yarın yenisi" : "\(puzzle.solved)/\(puzzle.total) kelime · ipuçları Türkçe"
    }

    private var remainingText: String {
        switch remaining {
        case nil: "Sınırsız tur"
        case 0?: "Bugünkü ücretsiz tur bitti"
        case let n?: "Bugün \(n) ücretsiz tur kaldı"
        }
    }
}

/// Ayarlar arrives in milestone 8.
struct SettingsPlaceholderView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Ayarlar")
                Text("Kelime listesi: New General Service List, CC BY-SA 4.0\nİçerik yapay zekâ ile üretildi ve kontrol edildi")
                    .font(KelimeFont.ui(12, relativeTo: .caption))
                    .foregroundStyle(Palette.ink2)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .hiddenNavigationBar()
    }
}

/// Stand-in until StoreKit and the real paywall land in milestone 7.
struct PaywallPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    let request: AppRouter.PaywallRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Kapat")
            }
            Text(request.trigger.headline(deck: request.deck))
                .font(KelimeFont.english(34, relativeTo: .largeTitle))
            Text("Reklam yok. Hesap yok. İnternetsiz çalışır.")
                .font(KelimeFont.ui(15, relativeTo: .body))
                .foregroundStyle(Palette.ink2)
            Spacer()
        }
        .padding(20)
        .screenBackground()
        .tint(Palette.ink)
    }
}
