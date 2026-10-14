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
            }
        }
    }
}

/// Oyna hub. Quick Review (milestone 5) and the crossword (milestone 6) plug in here.
struct PlayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Oyna")
                Text("Hızlı Tekrar ve Günün Bulmacası burada olacak.")
                    .font(KelimeFont.ui(15, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .hiddenNavigationBar()
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
