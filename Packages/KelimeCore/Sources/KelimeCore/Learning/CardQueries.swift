import Foundation
import GRDB

/// Narrow queries over cards. They fetch only the columns callers need, so they stay cheap
/// inside the widget extension's memory limit.
public enum CardQueries {
    /// Cards in any of `decks`, with their learning state. A card without a `card_state` row is new.
    public static func candidates(in decks: [DeckID], db: Database) throws -> [SchedulerCandidate] {
        guard let filter = deckFilter(decks) else { return [] }
        let request: SQLRequest<Row> = """
            SELECT c.id, COALESCE(s.state, 'new') AS state, s.last_shown_at
            FROM card c
            LEFT JOIN card_state s ON s.card_id = c.id
            WHERE \(filter)
            """
        return try request.fetchAll(db).map { row in
            SchedulerCandidate(
                cardID: row["id"],
                state: LearningState(rawValue: row["state"]) ?? .new,
                lastShownAt: row["last_shown_at"]
            )
        }
    }

    /// SQL condition matching cards that belong to any of `decks`. Nil when `decks` is empty.
    static func deckFilter(_ decks: [DeckID]) -> SQL? {
        let levels = decks.compactMap(\.level)
        let tags = decks.compactMap(\.tag)
        var clauses: [SQL] = []
        if !levels.isEmpty {
            clauses.append("(c.level IN \(levels) AND EXISTS (SELECT 1 FROM card_deck d WHERE d.card_id = c.id AND d.deck = \(DeckTag.general)))")
        }
        if !tags.isEmpty {
            clauses.append("EXISTS (SELECT 1 FROM card_deck d WHERE d.card_id = c.id AND d.deck IN \(tags))")
        }
        return clauses.isEmpty ? nil : "(\(clauses.joined(separator: " OR ")))"
    }

    /// Up to `count` distinct English words to use as wrong options for `card`.
    ///
    /// Prefers the same level and part of speech, then the same part of speech, then anything.
    public static func distractors(
        for card: Card,
        count: Int,
        db: Database,
        using rng: inout some RandomNumberGenerator
    ) throws -> [String] {
        var chosen: [String] = []
        var seen: Set<String> = [card.word]
        let tiers: [SQL] = [
            "level = \(card.level) AND pos = \(card.pos.rawValue)",
            "pos = \(card.pos.rawValue)",
            "1",
        ]
        for tier in tiers where chosen.count < count {
            let words = try String.fetchAll(db, SQLRequest<String>("SELECT word FROM card WHERE \(tier) AND id <> \(card.id) ORDER BY id"))
            for word in words.shuffled(using: &rng) where chosen.count < count && !seen.contains(word) {
                chosen.append(word)
                seen.insert(word)
            }
        }
        return chosen
    }

    /// The answer plus distractors, shuffled. Used by the medium quiz widget and Quick Review.
    public static func quizOptions(
        for card: Card,
        optionCount: Int,
        db: Database,
        using rng: inout some RandomNumberGenerator
    ) throws -> [String] {
        let wrong = try distractors(for: card, count: optionCount - 1, db: db, using: &rng)
        return ([card.word] + wrong).shuffled(using: &rng)
    }
}
