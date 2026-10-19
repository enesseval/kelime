import Foundation

/// A user-facing deck: a level deck (general words of one CEFR level) or an exam deck.
public enum DeckID: String, Codable, Sendable, CaseIterable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case yds = "YDS"
    case yokdil = "YÖKDİL"
    case ielts = "IELTS"

    /// Free users get the A1 course and the A2 and B1 general words; everything else is Pro.
    public var isPro: Bool {
        switch self {
        case .a1, .a2, .b1: false
        default: true
        }
    }

    /// For level decks, the level they hold.
    public var level: CEFRLevel? {
        switch self {
        case .a1: .a1
        case .a2: .a2
        case .b1: .b1
        case .b2: .b2
        case .c1: .c1
        case .yds, .yokdil, .ielts: nil
        }
    }

    /// For exam decks, the tag their cards carry.
    public var tag: DeckTag? {
        switch self {
        case .yds: .yds
        case .yokdil: .yokdil
        case .ielts: .ielts
        default: nil
        }
    }

    public static let freeDecks: [DeckID] = allCases.filter { !$0.isPro }

    /// The default word decks for a learner past the beginner course: A2 and B1. A1 is a
    /// course of its own and is only on for learners who pick it.
    public static let basicDecks: [DeckID] = [.a2, .b1]

    /// Enabled decks the user may actually use. Falls back to the basic decks so the widget
    /// always has something to show.
    public static func entitled(enabled: [DeckID], isPro: Bool) -> [DeckID] {
        let allowed = enabled.filter { isPro || !$0.isPro }
        return allowed.isEmpty ? basicDecks : allowed
    }
}
