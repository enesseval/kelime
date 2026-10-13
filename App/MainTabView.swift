import KelimeCore
import KelimeUI
import SwiftUI

/// The four tabs. Screens are filled in by later milestones.
struct MainTabView: View {
    let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
        Self.configureTabBarAppearance()
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

    var body: some View {
        TabView {
            PlaceholderScreen(title: "Bugün", database: database)
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            PlaceholderScreen(title: "Oyna", database: database)
                .tabItem { Label("Oyna", systemImage: "square.grid.3x3") }
            PlaceholderScreen(title: "Kelimelerim", database: database)
                .tabItem { Label("Kelimelerim", systemImage: "text.book.closed") }
            PlaceholderScreen(title: "Ayarlar", database: database)
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
        .tint(Palette.accent)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let database: AppDatabase
    @State private var cardCount: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if let cardCount {
                    Text("\(cardCount) kelime yüklendi")
                        .foregroundStyle(Palette.ink2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .navigationTitle(title)
        }
        .task {
            cardCount = try? await database.reader.read { db in try Card.fetchCount(db) }
        }
    }
}
