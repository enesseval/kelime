import Foundation
import KelimeCore
import Observation

/// Bundled daily puzzles, loaded per level on demand.
enum PuzzleLibrary {
    private static let cache = Cache()

    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var files: [CEFRLevel: [Crossword]] = [:]
    }

    static var availableLevels: [CEFRLevel] {
        CEFRLevel.allCases.filter { url(for: $0) != nil }
    }

    static func url(for level: CEFRLevel) -> URL? {
        Bundle.main.url(forResource: level.rawValue, withExtension: "json", subdirectory: "Content/puzzles")
    }

    static func puzzles(for level: CEFRLevel) -> [Crossword] {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        if let cached = cache.files[level] { return cached }
        guard let url = url(for: level),
              let data = try? Data(contentsOf: url),
              let file = try? DailyPuzzle.decode(data)
        else { return [] }
        cache.files[level] = file.puzzles
        return file.puzzles
    }

    /// The daily puzzle for `day` at the user's level (or the nearest level with puzzles).
    static func daily(for preferred: CEFRLevel, on day: LocalDate) -> (level: CEFRLevel, puzzle: Crossword)? {
        guard let level = DailyPuzzle.level(for: preferred, available: availableLevels),
              let puzzle = DailyPuzzle.pick(from: puzzles(for: level), on: day)
        else { return nil }
        return (level, puzzle)
    }
}

/// Today's puzzle state for the Bugün and Oyna cards.
struct DailyPuzzleInfo: Sendable {
    var level: CEFRLevel
    var solved: Int
    var total: Int
    var completed: Bool
    /// Letter cells (row * 8 + col on an 8-wide thumbnail) and whether their word is solved.
    var thumbnail: [Int: Bool]

    static func load(db: Database, clock: AppClock) throws -> DailyPuzzleInfo? {
        let prefs = try Preferences.load(db)
        guard let (level, puzzle) = PuzzleLibrary.daily(for: prefs.level, on: clock.today) else { return nil }
        let saved = try PuzzleStore.load(key: DailyPuzzle.key(level: level, day: clock.today), puzzle: puzzle, db: db)
        var cells: [Int: Bool] = [:]
        let columns = 8
        for entry in puzzle.entries {
            let solved = saved.game.isSolved(entry)
            for cell in entry.cells where cell.col < columns && cell.row < 10 {
                let index = cell.row * columns + cell.col
                cells[index] = (cells[index] ?? false) || solved
            }
        }
        return DailyPuzzleInfo(
            level: level,
            solved: saved.game.solvedCount,
            total: puzzle.entries.count,
            completed: saved.completedAt != nil,
            thumbnail: cells
        )
    }
}

/// Which puzzle a session plays.
enum PuzzleSource: Hashable {
    case daily(LocalDate)
    case personal
}

/// A crossword being played: the game state, clues, timer and persistence.
@MainActor
@Observable
final class PuzzleModel {
    let source: PuzzleSource
    private(set) var key = ""
    private(set) var game: CrosswordGame?
    private(set) var clues: [String: String] = [:]
    private(set) var cards: [String: Card] = [:]
    private(set) var seconds = 0
    private(set) var completedAt: Date?
    private(set) var failed = false
    private(set) var isDaily = true

    private weak var app: AppModel?

    init(source: PuzzleSource) {
        self.source = source
    }

    var title: String { isDaily ? "Günün Bulmacası" : "Sana Özel Bulmaca" }

    func load(app: AppModel) async {
        self.app = app
        guard game == nil else { return }
        let clock = app.clock
        let source = source
        let result: (String, Crossword, PuzzleStore.Saved, [Card], Bool)? = await app.read { db in
            let prefs = try Preferences.load(db)
            let key: String
            let puzzle: Crossword
            switch source {
            case .daily(let day):
                guard let (level, daily) = PuzzleLibrary.daily(for: prefs.level, on: day) else { return nil }
                key = DailyPuzzle.key(level: level, day: day)
                puzzle = daily
            case .personal:
                key = "personal-\(clock.today.string)"
                if let row = try PuzzleProgress.fetchOne(db, key: key + "-grid"),
                   let stored = try? JSONDecoder().decode(Crossword.self, from: Data(row.cells.utf8)) {
                    puzzle = stored
                } else {
                    let seed = UInt64(clock.today.dayIndex) &* 7919 &+ 17
                    guard let made = try PersonalPuzzle.make(db: db, clock: clock, seed: seed) else { return nil }
                    puzzle = made
                }
            }
            let saved = try PuzzleStore.load(key: key, puzzle: puzzle, db: db)
            let cards = try Card.fetchAll(db, keys: puzzle.entries.map(\.cardID))
            if case .daily = source { return (key, puzzle, saved, cards, true) }
            return (key, puzzle, saved, cards, false)
        } ?? nil

        guard let (key, puzzle, saved, cards, isDaily) = result else { failed = true; return }
        self.key = key
        self.isDaily = isDaily
        self.cards = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        clues = Dictionary(uniqueKeysWithValues: puzzle.entries.map { entry in
            (entry.id, DailyPuzzle.clue(meaning: self.cards[entry.cardID]?.meaning ?? "", length: entry.length))
        })
        game = saved.game
        seconds = saved.seconds
        completedAt = saved.completedAt
        if !isDaily { await storePersonalGrid(puzzle) }
    }

    /// The personal puzzle is generated once per day and kept, so reopening shows the same grid.
    private func storePersonalGrid(_ puzzle: Crossword) async {
        guard let app, let data = try? JSONEncoder().encode(puzzle) else { return }
        let key = key + "-grid"
        let text = String(decoding: data, as: UTF8.self)
        try? await app.database?.writer.write { db in
            if try PuzzleProgress.fetchOne(db, key: key) == nil {
                try PuzzleProgress(puzzleKey: key, cells: text).insert(db)
            }
        }
    }

    // MARK: - Play

    var isComplete: Bool { completedAt != nil }

    func tick() {
        guard !isComplete, game != nil else { return }
        seconds += 1
        if seconds % 10 == 0 { Task { await save() } }
    }

    func type(_ letter: Character) {
        game?.type(letter)
        afterChange()
    }

    func deleteBackward() {
        game?.deleteBackward()
        afterChange()
    }

    func select(_ point: GridPoint) {
        game?.select(point)
    }

    func step(_ delta: Int) {
        game?.step(delta)
    }

    func focus(_ entry: CrosswordEntry) {
        game?.focus(entry)
    }

    func revealLetter() {
        guard let entry = game?.revealLetter() else { return }
        Task { await recordHint(entry) }
        afterChange()
    }

    func checkWord() {
        guard var g = game else { return }
        let entry = g.activeEntry
        let error = g.checkWord()
        game = g
        if error { Task { await recordHint(entry) } }
        afterChange()
    }

    func revealWord() {
        guard let entry = game?.revealWord() else { return }
        Task { await recordHint(entry) }
        afterChange()
    }

    private func afterChange() {
        guard let game else { return }
        if game.isComplete && completedAt == nil {
            completedAt = Date()
            Task { await finish() }
        } else {
            Task { await save() }
        }
    }

    private func recordHint(_ entry: CrosswordEntry) async {
        guard let app else { return }
        let clock = app.clock
        await app.write(rebuildQueue: false) { db in
            try PuzzleStore.recordHint(for: entry, clock: clock, db: db)
        }
    }

    func save() async {
        guard let app, let game, let database = app.database else { return }
        let key = key, seconds = seconds, completedAt = completedAt, isDaily = isDaily, source = source
        let summary = DailyPuzzleSummary(day: app.clock.today, solved: game.solvedCount, total: game.puzzle.entries.count)
        try? await database.writer.write { db in
            try PuzzleStore.save(key: key, game: game, seconds: seconds, completedAt: completedAt, db: db)
            if isDaily, case .daily(let day) = source, day == summary.day { try summary.save(db: db) }
        }
    }

    private func finish() async {
        await save()
        guard let app, let game else { return }
        let clock = app.clock
        await app.write(rebuildQueue: false) { db in
            try PuzzleStore.recordCompletion(game, clock: clock, db: db)
        }
    }

    // MARK: - Completion

    /// Words the user needed help with; they're now on the widget more often.
    var helpedWords: [Card] {
        guard let game else { return [] }
        return game.puzzle.orderedEntries.filter { game.helped.contains($0.id) }.compactMap { cards[$0.cardID] }
    }

    var timeText: String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
