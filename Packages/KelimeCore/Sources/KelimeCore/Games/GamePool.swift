import Foundation
import GRDB

/// Words for the games, in the same study order as Quick Review, from the widget's sources.
public enum GamePool {
    /// Up to `count` cards. `singleWords` keeps plain A–Z words of `lengths`, for letter grids.
    public static func cards(
        count: Int,
        singleWords: Bool,
        lengths: ClosedRange<Int> = 1...40,
        excluding: Set<String> = [],
        where isEligible: (Card) -> Bool = { _ in true },
        db: Database,
        today: LocalDate,
        using rng: inout some RandomNumberGenerator
    ) throws -> [Card] {
        // A window from the front of the study order, shuffled, so rounds vary but still lean
        // on struggling and freshly shown words.
        let ids = try QuickReview.orderedCardIDs(db: db, today: today, using: &rng).filter { !excluding.contains($0) }
        var picked: [Card] = []
        var seenWords = Set<String>()
        var offset = 0
        let batch = 60
        while picked.count < count && offset < ids.count {
            let window = Array(ids[offset..<min(ids.count, offset + batch)])
            offset += batch
            let cards = try Card.fetchAll(db, keys: window)
            let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
            for id in window.shuffled(using: &rng) {
                guard picked.count < count, let card = byID[id] else { continue }
                if !isEligible(card) { continue }
                if singleWords && !(card.isSingleWord && lengths.contains(card.word.count)) { continue }
                let key = card.word.lowercased()
                guard seenWords.insert(key).inserted else { continue }
                picked.append(card)
            }
        }
        return picked
    }

    /// The best score of a game, from its stored results (Eşleştir keeps its own setting).
    public static func best(_ game: StreakSource, db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT MAX(score) FROM game_result WHERE game = ?", arguments: [game.rawValue]) ?? 0
    }

    /// Records a finished round for the streak and the best scores.
    public static func recordResult(
        game: StreakSource,
        score: Int,
        total: Int,
        seconds: Int,
        clock: AppClock,
        db: Database
    ) throws {
        try db.execute(
            sql: "INSERT INTO game_result (game, played_at, played_on, score, total, seconds) VALUES (?, ?, ?, ?, ?, ?)",
            arguments: [game.rawValue, clock.now, clock.today, score, total, seconds]
        )
        try Streak.record(game, on: clock.today, db: db)
        if game == .match, score > (try Settings.int(.matchBest, in: db) ?? 0) {
            try Settings.set(.matchBest, score, in: db)
        }
    }
}
