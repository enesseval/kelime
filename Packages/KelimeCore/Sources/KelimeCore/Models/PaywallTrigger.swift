import Foundation

/// Why the paywall opened. The headline adapts to it; the paywall never opens on first launch.
public enum PaywallTrigger: String, Sendable, CaseIterable, Identifiable {
    case base
    case lists
    case share
    case rotation
    case personalPuzzle
    case archive
    case examPlan
    case discover

    public var id: String { rawValue }

    public func headline(deck: DeckID? = nil) -> String {
        switch self {
        case .base: "Kilit Kelime Pro"
        case .lists: "Sınırsız kendi listen"
        case .share: "Listeni paylaş"
        case .rotation: "Daha sık yeni kelime"
        case .personalPuzzle: "Sana özel bulmaca"
        case .archive: "Bulmaca arşivi"
        case .examPlan: "Sınav planı"
        case .discover: "Keşfet'ten hazır listeler"
        }
    }
}
