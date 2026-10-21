import Foundation
import GRDB

/// Narrow queries over cards. They fetch only the columns callers need, so they stay cheap
/// inside the widget extension's memory limit.
public enum CardQueries {
    /// Cards in any of `decks`, with their learning state. A card without a `card_state` row is new.
    /// Course cards count only once their unit is started.
    public static func candidates(in decks: [DeckID], db: Database) throws -> [SchedulerCandidate] {
        guard let filter = try deckFilter(decks, started: Curriculum.startedFilter(db: db)) else { return [] }
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
    /// `started` limits level decks to started course units; exam decks take their words from
    /// every level, started or not.
    static func deckFilter(_ decks: [DeckID], started: SQL = "1") -> SQL? {
        let levels = decks.compactMap(\.level)
        let tags = decks.compactMap(\.tag)
        var clauses: [SQL] = []
        if !levels.isEmpty {
            clauses.append("(c.level IN \(levels) AND EXISTS (SELECT 1 FROM card_deck d WHERE d.card_id = c.id AND d.deck = \(DeckTag.general)) AND \(started))")
        }
        if !tags.isEmpty {
            clauses.append("EXISTS (SELECT 1 FROM card_deck d WHERE d.card_id = c.id AND d.deck IN \(tags))")
        }
        return clauses.isEmpty ? nil : "(\(clauses.joined(separator: " OR ")))"
    }

    /// Up to `count` distinct English words to use as wrong options for `card`.
    ///
    /// Prefers the same level and part of speech, then the same part of speech, then anything.
    /// Words that share a Turkish meaning with `card` are never offered: both would be right.
    /// Phrases are only compared with phrases, words only with words.
    public static func distractors(
        for card: Card,
        count: Int,
        db: Database,
        using rng: inout some RandomNumberGenerator
    ) throws -> [String] {
        var chosen: [String] = []
        var seen: Set<String> = [card.word]
        let meanings = Card.normalizedMeanings(card.tr)
        let phrase = PartOfSpeech.phrase.rawValue
        let tiers: [SQL] = [
            "level = \(card.level) AND pos = \(card.pos.rawValue)",
            "pos = \(card.pos.rawValue)",
            card.isPhrase ? "pos = \(phrase)" : "pos <> \(phrase)",
        ]
        for tier in tiers where chosen.count < count {
            let cards = try Card.fetchAll(db, SQLRequest<Card>("SELECT * FROM card WHERE \(tier) AND id <> \(card.id) ORDER BY id"))
            for other in cards.shuffled(using: &rng) where chosen.count < count && !seen.contains(other.word) {
                guard Card.normalizedMeanings(other.tr).isDisjoint(with: meanings) else { continue }
                chosen.append(other.word)
                seen.insert(other.word)
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
