import KelimeCore
import KelimeUI
import SwiftUI

/// 9:16 story image for sharing a word: the word, meaning and example large, a small wordmark.
struct ShareCardView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            LevelChip(card.level, size: 16)
            Text(card.word)
                .font(KelimeFont.english(card.word.count > 11 ? 52 : 68))
                .tracking(-1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 18)
            (Text(card.pos.abbreviation).font(KelimeFont.english(22, italic: true)).foregroundStyle(Palette.ink2)
                + Text("  ") + Text(card.meaning).font(KelimeFont.ui(24)))
                .padding(.top, 10)
            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 28)
            Text(card.exampleEN).font(KelimeFont.english(26, italic: true))
            Text(card.exampleTR).font(KelimeFont.ui(18)).foregroundStyle(Palette.ink2).padding(.top, 6)
            Spacer()
            Text(AppDisplayName.value)
                .font(KelimeFont.ui(14, weight: .semibold))
                .foregroundStyle(Palette.ink2)
        }
        .foregroundStyle(Palette.ink)
        .padding(36)
        .frame(width: 360, height: 640, alignment: .leading)
        .background(Palette.paper)
        .environment(\.colorScheme, .light)
    }
}

enum ShareCardRenderer {
    /// Renders at 3× (1080 × 1920).
    @MainActor
    static func image(for card: Card) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(card: card))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The display name, read from the bundle so it lives only in `Config/Shared.xcconfig`.
enum AppDisplayName {
    static let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Kelime Widget"
}
