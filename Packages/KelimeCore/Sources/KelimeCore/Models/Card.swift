import Foundation
import GRDB

public enum PartOfSpeech: String, Codable, Sendable, CaseIterable {
    case adjective = "adj"
    case noun = "n"
    case verb = "v"
    case adverb = "adv"

    /// Short label shown on cards, e.g. "adj.".
    public var abbreviation: String { rawValue + "." }
}

public enum CEFRLevel: String, Codable, Sendable, CaseIterable, Comparable, DatabaseValueConvertible {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    public static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// Tag decks a card can belong to. Level decks (A1…C1) come from `Card.level`, not from here.
public enum DeckTag: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case general
    case yds
    case yokdil
    case ielts
}

/// One vocabulary card. Read-only content imported from `Content/cards.json`.
public struct Card: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var word: String
    public var pos: PartOfSpeech
    public var level: CEFRLevel
    /// Turkish meanings, 1–2 entries.
    public var tr: [String]
    public var exampleEN: String
    public var exampleTR: String

    public init(id: String, word: String, pos: PartOfSpeech, level: CEFRLevel, tr: [String], exampleEN: String, exampleTR: String) {
        self.id = id
        self.word = word
        self.pos = pos
        self.level = level
        self.tr = tr
        self.exampleEN = exampleEN
        self.exampleTR = exampleTR
    }

    /// Meanings joined for display: "isteksiz, gönülsüz".
    public var meaning: String { tr.joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case id, word, pos, level, tr
        case exampleEN = "example_en"
        case exampleTR = "example_tr"
    }
}

extension Card: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let word = Column(CodingKeys.word)
        public static let pos = Column(CodingKeys.pos)
        public static let level = Column(CodingKeys.level)
    }
}

/// Membership of a card in a tag deck.
public struct CardDeck: Codable, Sendable, Hashable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card_deck"

    public var cardID: String
    public var deck: DeckTag

    public init(cardID: String, deck: DeckTag) {
        self.cardID = cardID
        self.deck = deck
    }

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
        case deck
    }
}
