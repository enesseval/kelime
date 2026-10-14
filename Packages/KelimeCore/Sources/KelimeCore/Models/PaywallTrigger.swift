import Foundation

/// Why the paywall opened. The headline adapts to it; the paywall never opens on first launch.
public enum PaywallTrigger: String, Sendable, CaseIterable, Identifiable {
    case base
    case reviewLimit
    case proDeck
    case archive
    case theme
    case rotation
    case personalPuzzle

    public var id: String { rawValue }

    public func headline(deck: DeckID? = nil) -> String {
        switch self {
        case .base: "Kelime Widget Pro"
        case .reviewLimit: "Sınırsız tekrar"
        case .proDeck: deck.map { "\($0.rawValue) destesini aç" } ?? "Tüm desteleri aç"
        case .archive: "Bulmaca arşivini aç"
        case .theme: "Tüm temaları aç"
        case .rotation: "30 dakikada bir yeni kelime"
        case .personalPuzzle: "Sana özel bulmaca"
        }
    }
}
