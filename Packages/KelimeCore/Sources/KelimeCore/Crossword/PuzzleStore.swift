import Foundation
import GRDB

/// Saves and restores crossword progress, and turns hints and solved words into learning events.
public enum PuzzleStore {
    public struct Saved: Sendable {
        public var game: CrosswordGame
        public var seconds: Int
        public var completedAt: Date?
    }

    /// Saved progress for `key`, or a fresh game when there is none or it was saved for a
    /// different grid.
    public static func load(key: String, puzzle: Crossword, db: Database) throws -> Saved {
        guard let row = try PuzzleProgress.fetchOne(db, key: key),
              let snapshot = try? CrosswordGame.decodeSnapshot(row.cells),
              snapshot.grid == puzzle.fingerprint
        else { return Saved(game: CrosswordGame(puzzle: puzzle), seconds: 0, completedAt: nil) }
        return Saved(game: CrosswordGame(puzzle: puzzle, snapshot: snapshot), seconds: row.seconds, completedAt: row.completedAt)
    }

    /// Forgets progress for `key` (and a stored personal grid), so the puzzle starts over.
    public static func reset(key: String, db: Database) throws {
        _ = try PuzzleProgress.deleteAll(db, keys: [key, key + "-grid"])
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
    /// Letter cells of an 8 × 10 thumbnail (row * 8 + col) and whether their word is solved.
    public var cells: [Int: Bool]

    public init(day: LocalDate, solved: Int, total: Int, cells: [Int: Bool] = [:]) {
        self.day = day
        self.solved = solved
        self.total = total
        self.cells = cells
    }

    public init(day: LocalDate, game: CrosswordGame) {
        self.init(day: day, solved: game.solvedCount, total: game.puzzle.entries.count, cells: Self.thumbnail(game))
    }

    /// The top-left 8 × 10 of the grid: letter cells, green once their word is solved.
    public static func thumbnail(_ game: CrosswordGame) -> [Int: Bool] {
        var cells: [Int: Bool] = [:]
        for entry in game.puzzle.entries {
            let solved = game.isSolved(entry)
            for cell in entry.cells where cell.col < 8 && cell.row < 10 {
                let index = cell.row * 8 + cell.col
                cells[index] = (cells[index] ?? false) || solved
            }
        }
        return cells
    }

    public static func load(db: Database) throws -> DailyPuzzleSummary? {
        guard let raw = try Settings.string(.dailyPuzzleSummary, in: db) else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3, let day = LocalDate(string: String(parts[0])),
              let solved = Int(parts[1]), let total = Int(parts[2]) else { return nil }
        var cells: [Int: Bool] = [:]
        if parts.count > 3 {
            for item in parts[3].split(separator: ",") {
                let pair = item.split(separator: ":")
                if pair.count == 2, let index = Int(pair[0]) { cells[index] = pair[1] == "1" }
            }
        }
        return DailyPuzzleSummary(day: day, solved: solved, total: total, cells: cells)
    }

    public func save(db: Database) throws {
        let grid = cells.keys.sorted().map { "\($0):\(cells[$0] == true ? 1 : 0)" }.joined(separator: ",")
        try Settings.set(.dailyPuzzleSummary, "\(day.string)|\(solved)|\(total)|\(grid)", in: db)
    }
}
