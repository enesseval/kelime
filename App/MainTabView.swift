import KelimeCore
import KelimeUI
import SwiftUI

/// The four tabs. Screens are filled in by later milestones.
struct MainTabView: View {
    let database: AppDatabase

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
