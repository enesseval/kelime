import Foundation

/// Eşleştir: a timed round of matching English words to their Turkish meanings. Five pairs are
/// on the board; a matched pair leaves its slots empty, and once three pairs are gone the next
/// three cards fill the empty slots in a random order. Pure state, so the view only renders it.
public struct MatchGame: Sendable {
    public static let duration: TimeInterval = 60
    public static let boardSize = 5
    /// Empty slots per side that bring the next cards in.
    public static let refillAt = 3

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
    private var rng: SeededGenerator

    public init(cards: [Card], seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        rng = SeededGenerator(seed: seed)
        let board = Array(cards.prefix(Self.boardSize))
        queue = Array(cards.dropFirst(Self.boardSize))
        english = board.map { Tile(card: $0, side: .english) }.shuffled(using: &rng)
        turkish = board.map { Tile(card: $0, side: .turkish) }.shuffled(using: &rng)
        // No pair starts on the same row.
        if turkish.count > 1 {
            for i in turkish.indices where turkish[i]?.card.id == english[i]?.card.id {
                turkish.swapAt(i, (i + 1) % turkish.count)
            }
            for i in turkish.indices where turkish[i]?.card.id == english[i]?.card.id {
                turkish.swapAt(i, (i + turkish.count - 1) % turkish.count)
            }
        }
    }

    public var isOutOfCards: Bool { english.allSatisfy { $0 == nil } && turkish.allSatisfy { $0 == nil } }

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
            refill(englishOf: en.card, turkishOf: tr.card)
            return .match(en.card)
        }
        if missedIDs.insert(en.card.id).inserted { missed.append(en.card) }
        return .miss(english: en.card, turkish: tr.card)
    }

    /// Empties the matched slots; once enough are empty, deals the next cards into them.
    private mutating func refill(englishOf matchedEnglish: Card, turkishOf matchedTurkish: Card) {
        // A synonym pair (two cards, one meaning) leaves each card's other half behind; those
        // two halves share the meaning too, so they still match each other.
        if let ei = english.firstIndex(where: { $0?.card.id == matchedEnglish.id }) { english[ei] = nil }
        if let ti = turkish.firstIndex(where: { $0?.card.id == matchedTurkish.id }) { turkish[ti] = nil }
        let emptyEnglish = english.indices.filter { english[$0] == nil }
        let emptyTurkish = turkish.indices.filter { turkish[$0] == nil }
        let boardEmpty = emptyEnglish.count == english.count
        guard emptyEnglish.count >= Self.refillAt || boardEmpty, !queue.isEmpty else { return }

        let cards = Array(queue.prefix(min(emptyEnglish.count, emptyTurkish.count)))
        queue.removeFirst(cards.count)
        // Random slots, but a new card's halves never land on the same row.
        var englishSlots = emptyEnglish.shuffled(using: &rng)
        var turkishSlots = emptyTurkish.shuffled(using: &rng)
        for _ in 0..<20 where zip(englishSlots.prefix(cards.count), turkishSlots).contains(where: ==) {
            englishSlots.shuffle(using: &rng)
            turkishSlots.shuffle(using: &rng)
        }
        for (i, card) in cards.enumerated() {
            english[englishSlots[i]] = Tile(card: card, side: .english)
            turkish[turkishSlots[i]] = Tile(card: card, side: .turkish)
        }
    }
}
