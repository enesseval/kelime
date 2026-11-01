import Foundation

/// Eşleştir: a timed round of matching English words to their Turkish meanings. Five pairs are
/// on the board; a matched pair leaves and the next card takes its place. Pure state, so the
/// view only renders it.
public struct MatchGame: Sendable {
    public static let duration: TimeInterval = 60
    public static let boardSize = 5

    public struct Tile: Identifiable, Sendable, Equatable {
        public enum Side: Sendable { case english, turkish }
        public var card: Card
        public var side: Side
        public var id: String { card.id + (side == .english ? "-en" : "-tr") }
        public var text: String { side == .english ? card.word : card.primaryMeaning }
    }

    public enum Outcome: Sendable, Equatable {
        case match(Card)
        /// The English card chosen and the Turkish card it was wrongly paired with.
        case miss(english: Card, turkish: Card)
    }

    public private(set) var english: [Tile?]
    public private(set) var turkish: [Tile?]
    public private(set) var selected: Tile?
    public private(set) var score = 0
    /// Cards matched right on the first try, and cards missed at least once.
    public private(set) var firstTry: [Card] = []
    public private(set) var missed: [Card] = []
    private var queue: [Card]
    private var missedIDs = Set<String>()

    public init(cards: [Card], using rng: inout some RandomNumberGenerator) {
        let board = Array(cards.prefix(Self.boardSize))
        queue = Array(cards.dropFirst(Self.boardSize))
        english = board.map { Tile(card: $0, side: .english) }.shuffled(using: &rng)
        turkish = board.map { Tile(card: $0, side: .turkish) }.shuffled(using: &rng)
    }

    public var isOutOfCards: Bool { english.allSatisfy { $0 == nil } && queue.isEmpty }

    /// Taps a tile. The first tap selects; a tap on the other side pairs them. Returns the
    /// outcome of a pair, nil for a selection.
    @discardableResult
    public mutating func tap(_ tile: Tile) -> Outcome? {
        guard let first = selected else {
            selected = tile
            return nil
        }
        if first.side == tile.side {
            selected = tile
            return nil
        }
        selected = nil
        let en = first.side == .english ? first : tile
        let tr = first.side == .turkish ? first : tile
        // Two cards sharing a meaning both count: the pair is right if the meanings agree.
        if en.card.id == tr.card.id || Card.normalizedMeanings(en.card.tr) == Card.normalizedMeanings(tr.card.tr) {
            score += 1
            if !missedIDs.contains(en.card.id) { firstTry.append(en.card) }
            replace(en.card.id)
            if en.card.id != tr.card.id { replace(tr.card.id) }
            return .match(en.card)
        }
        if missedIDs.insert(en.card.id).inserted { missed.append(en.card) }
        return .miss(english: en.card, turkish: tr.card)
    }

    private mutating func replace(_ cardID: String) {
        let next = queue.isEmpty ? nil : queue.removeFirst()
        if let i = english.firstIndex(where: { $0?.card.id == cardID }) {
            english[i] = next.map { Tile(card: $0, side: .english) }
        }
        if let i = turkish.firstIndex(where: { $0?.card.id == cardID }) {
            // The new Turkish card goes to a different row than its English card when possible,
            // so a fresh pair never lines up straight across.
            turkish[i] = next.map { Tile(card: $0, side: .turkish) }
        }
        if let next, let ei = english.firstIndex(where: { $0?.card.id == next.id }),
           let ti = turkish.firstIndex(where: { $0?.card.id == next.id }), ei == ti,
           let swap = turkish.indices.first(where: { $0 != ti && turkish[$0] != nil }) {
            turkish.swapAt(ti, swap)
        }
    }
}
