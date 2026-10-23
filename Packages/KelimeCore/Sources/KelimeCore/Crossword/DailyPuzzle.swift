import Foundation
import GRDB

/// Shape of `Content/puzzles/<LEVEL>.json`.
public struct PuzzleFile: Codable, Sendable {
    public var level: String
    public var puzzles: [Crossword]
}

public enum DailyPuzzle {
    /// Today's puzzle: `puzzles[dayIndex % count]`. Wraps when the content runs out, so it
    /// never fails; everyone at a level gets the same puzzle on the same local day.
    public static func pick(from puzzles: [Crossword], on day: LocalDate) -> Crossword? {
        guard !puzzles.isEmpty else { return nil }
        let n = puzzles.count
        return puzzles[((day.dayIndex % n) + n) % n]
    }

    public static func decode(_ data: Data) throws -> PuzzleFile {
        try JSONDecoder().decode(PuzzleFile.self, from: data)
    }

    /// Level whose puzzles to use: the user's level, or the nearest one that has puzzles.
    public static func level(for preferred: CEFRLevel, available: [CEFRLevel]) -> CEFRLevel? {
        guard !available.isEmpty else { return nil }
        if available.contains(preferred) { return preferred }
        return available.min { abs(index($0) - index(preferred)) < abs(index($1) - index(preferred)) }
    }

    private static func index(_ level: CEFRLevel) -> Int { CEFRLevel.allCases.firstIndex(of: level)! }

    /// Progress key for a daily puzzle.
    public static func key(level: CEFRLevel, day: LocalDate) -> String {
        "daily-\(level.rawValue)-\(day.string)"
    }

    /// Clue text: the card's Turkish meaning plus the letter count, e.g. "tereddüt etmek (8)".
    public static func clue(meaning: String, length: Int) -> String {
        "\(meaning) (\(length))"
    }
}

/// Builds the Pro personal puzzle: struggling words as seeds, filled with learned words (to keep
/// them fresh), or with the other words of the enabled decks while few are learned.
public enum PersonalPuzzle {
    public static func make(db: Database, clock: AppClock, seed: UInt64) throws -> Crossword? {
        let prefs = try Preferences.load(db)
        let struggling = try WidgetTimelineBuilder.strugglingCards(db: db, limit: 12)
            .filter { $0.isSingleWord && (3...CrosswordGenerator.maxSize).contains($0.word.count) }
        let seeds = struggling.prefix(4).map(CrosswordGenerator.Word.init(card:))
        let levelDeck = DeckID.allCases.first { $0.level == prefs.level }
        let decks = prefs.entitledDecks + (levelDeck.map { [$0] } ?? [])
        let ids = try CardQueries.candidates(in: decks, db: db).map(\.cardID)
        let usable = try Card.fetchAll(db, keys: ids)
            .filter { $0.isSingleWord && (3...CrosswordGenerator.maxSize).contains($0.word.count) }
        let learnedIDs = Set(try String.fetchAll(db, sql: "SELECT card_id FROM card_state WHERE state = ?", arguments: [LearningState.learned]))
        let learned = usable.filter { learnedIDs.contains($0.id) }
        let fillers = (learned.count >= 12 ? learned : usable).map(CrosswordGenerator.Word.init(card:))
        return CrosswordGenerator.generate(
            id: "personal-\(clock.today.string)-\(seed)",
            seeds: Array(seeds),
            fillers: fillers,
            seed: seed
        )
    }
}
