import KelimeCore
import KelimeUI
import SwiftUI

/// Looks of the share image.
enum ShareCardStyle: String, CaseIterable, Identifiable {
    case light
    case dark
    case blue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Açık"
        case .dark: "Koyu"
        case .blue: "Mavi"
        }
    }

    var scheme: ColorScheme { self == .light ? .light : .dark }

    var background: Color {
        switch self {
        case .light: Palette.paper
        case .dark: Color(red: 0.07, green: 0.067, blue: 0.063)
        case .blue: Color(red: 0.13, green: 0.22, blue: 0.42)
        }
    }
}

/// 9:16 story image for sharing a word: the word, meaning and example large, a small wordmark.
struct ShareCardView: View {
    let card: Card
    var style: ShareCardStyle = .light

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
            (Text(card.pos.label).font(KelimeFont.english(22, italic: true)).foregroundStyle(Palette.ink2)
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
        .background(style.background)
        .environment(\.colorScheme, style.scheme)
    }
}

enum ShareCardRenderer {
    /// Renders at 3× (1080 × 1920).
    @MainActor
    static func image(for card: Card, style: ShareCardStyle = .light) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(card: card, style: style))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// Picks the look of the share image, then hands it to the share sheet.
struct ShareCardSheet: View {
    let card: Card
    @Environment(\.dismiss) private var dismiss
    @State private var style: ShareCardStyle = .light
    @State private var images: [ShareCardStyle: Image] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TabView(selection: $style) {
                    ForEach(ShareCardStyle.allCases) { style in
                        ShareCardView(card: card, style: style)
                            .scaleEffect(0.78)
                            .frame(width: 360 * 0.78, height: 640 * 0.78)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                            .tag(style)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 640 * 0.78 + 30)
                Picker("Görünüm", selection: $style) {
                    ForEach(ShareCardStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                if let image = images[style] {
                    ShareLink(item: image, preview: SharePreview(card.word, image: image)) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                            .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(Palette.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .screenBackground()
            .navigationTitle("Kartı paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Kapat") { dismiss() } }
            }
            .task {
                for style in ShareCardStyle.allCases {
                    images[style] = ShareCardRenderer.image(for: card, style: style)
                }
            }
        }
    }
}

/// The display name, read from the bundle so it lives only in `Config/Shared.xcconfig`.
enum AppDisplayName {
    static let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Kilit Kelime"
}
