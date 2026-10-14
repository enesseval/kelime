import Foundation
import GRDB

/// Saves and restores crossword progress, and turns hints and solved words into learning events.
public enum PuzzleStore {
    public struct Saved: Sendable {
        public var game: CrosswordGame
        public var seconds: Int
        public var completedAt: Date?
    }

    public static func load(key: String, puzzle: Crossword, db: Database) throws -> Saved {
        guard let row = try PuzzleProgress.fetchOne(db, key: key),
              let snapshot = try? CrosswordGame.decodeSnapshot(row.cells)
        else { return Saved(game: CrosswordGame(puzzle: puzzle), seconds: 0, completedAt: nil) }
        return Saved(game: CrosswordGame(puzzle: puzzle, snapshot: snapshot), seconds: row.seconds, completedAt: row.completedAt)
    }

    public static func save(key: String, game: CrosswordGame, seconds: Int, completedAt: Date?, db: Database) throws {
        try PuzzleProgress(
            puzzleKey: key,
            cells: try game.encodedSnapshot(),
            hintsUsed: game.hintsUsed,
            completedAt: completedAt,
            seconds: seconds
        ).save(db)
    }

    /// A hint was used on `entry`: the word becomes struggling.
    public static func recordHint(for entry: CrosswordEntry, clock: AppClock, db: Database) throws {
        try LearningStore.record(.hintUsed, cardID: entry.cardID, source: .puzzle, clock: clock, db: db)
    }

    /// The puzzle is done: words solved without help count as correct answers.
    public static func recordCompletion(_ game: CrosswordGame, clock: AppClock, db: Database) throws {
        for entry in game.unaidedEntries {
            try LearningStore.record(.answered(correct: true), cardID: entry.cardID, source: .puzzle, clock: clock, db: db)
        }
    }
}

/// Today's daily puzzle progress in a form the widget can read without the puzzle files.
public struct DailyPuzzleSummary: Sendable, Equatable {
    public var day: LocalDate
    public var solved: Int
    public var total: Int

    public init(day: LocalDate, solved: Int, total: Int) {
        self.day = day
        self.solved = solved
        self.total = total
    }

    public static func load(db: Database) throws -> DailyPuzzleSummary? {
        guard let raw = try Settings.string(.dailyPuzzleSummary, in: db) else { return nil }
        let parts = raw.split(separator: "|")
        guard parts.count == 3, let day = LocalDate(string: String(parts[0])),
              let solved = Int(parts[1]), let total = Int(parts[2]) else { return nil }
        return DailyPuzzleSummary(day: day, solved: solved, total: total)
    }

    public func save(db: Database) throws {
        try Settings.set(.dailyPuzzleSummary, "\(day.string)|\(solved)|\(total)", in: db)
    }
}
