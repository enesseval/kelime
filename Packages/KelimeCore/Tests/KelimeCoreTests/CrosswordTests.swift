import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct CrosswordTests {
    /// The design's sample grid (8 × 10).
    static let sample = Crossword(id: "sample", width: 8, height: 10, entries: [
        CrosswordEntry(number: 1, direction: .across, row: 0, col: 2, answer: "BORROW", cardID: "a2-borrow"),
        CrosswordEntry(number: 2, direction: .down, row: 0, col: 3, answer: "OBVIOUS", cardID: "b1-obvious"),
        CrosswordEntry(number: 3, direction: .across, row: 3, col: 0, answer: "HESITATE", cardID: "b2-hesitate"),
        CrosswordEntry(number: 4, direction: .down, row: 3, col: 5, answer: "ACHIEVE", cardID: "b1-achieve"),
        CrosswordEntry(number: 5, direction: .across, row: 9, col: 1, answer: "ANCIENT", cardID: "b1-ancient"),
    ])

    static func cards() throws -> [String: Card] {
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        return Dictionary(uniqueKeysWithValues: file.cards.map { ($0.card.id, $0.card) })
    }

    static func puzzleFiles() throws -> [URL] {
        let dir = TestSupport.repoRoot.appendingPathComponent("Content/puzzles")
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Validator

    @Test func sampleGridIsValid() {
        #expect(CrosswordValidator.problems(Self.sample).isEmpty)
    }

    @Test func validatorCatchesBrokenGrids() {
        var conflict = Self.sample
        conflict.entries[1].answer = "XBVIOUS"
        #expect(CrosswordValidator.problems(conflict).contains(.conflict(GridPoint(0, 3))))

        var touching = Self.sample
        touching.entries.append(CrosswordEntry(number: 6, direction: .across, row: 1, col: 4, answer: "AB", cardID: "x"))
        #expect(!CrosswordValidator.isValid(touching))

        var outside = Self.sample
        outside.entries[2].col = 3
        #expect(CrosswordValidator.problems(outside).contains(.outOfBounds("3a")))

        var numbering = Self.sample
        numbering.entries[4].number = 9
        #expect(CrosswordValidator.problems(numbering).contains(.badNumbering("9a")))
    }

    // MARK: - Bundled daily puzzles

    @Test func everyBundledPuzzleIsValid() throws {
        let cards = try Self.cards()
        let files = try Self.puzzleFiles()
        #expect(files.map(\.lastPathComponent) == ["A2.json", "B1.json", "B2.json", "C1.json"])
        for url in files {
            let file = try DailyPuzzle.decode(Data(contentsOf: url))
            #expect(file.puzzles.count >= 365, "\(url.lastPathComponent) has too few puzzles")
            #expect(Set(file.puzzles.map(\.id)).count == file.puzzles.count)
            for puzzle in file.puzzles {
                let problems = CrosswordValidator.problems(puzzle)
                #expect(problems.isEmpty, "\(puzzle.id): \(problems)")
                #expect(puzzle.width <= 10 && puzzle.height <= 10)
                #expect(puzzle.entries.count >= 6)
                var seenMeanings = Set<String>()
                for entry in puzzle.entries {
                    let card = try #require(cards[entry.cardID], "\(puzzle.id): unknown card \(entry.cardID)")
                    // Two answers with the same meaning would get the same clue.
                    let meanings = Card.normalizedMeanings(card.tr)
                    #expect(seenMeanings.isDisjoint(with: meanings), "\(puzzle.id): \(card.word) repeats a clue")
                    seenMeanings.formUnion(meanings)
                    #expect(entry.answer == ReviewQuestion.asciiUpper(card.word))
                    #expect(card.level.rawValue == file.level)
                    // The clue is the card's meaning plus the letter count.
                    #expect(DailyPuzzle.clue(meaning: card.meaning, length: entry.length) == "\(card.meaning) (\(card.word.count))")
                }
            }
        }
    }

    @Test func dailyPickWrapsAndIsStable() {
        let puzzles = (0..<3).map { Crossword(id: "p\($0)", width: 1, height: 1, entries: []) }
        let day = LocalDate.epoch
        #expect(DailyPuzzle.pick(from: puzzles, on: day)?.id == "p0")
        #expect(DailyPuzzle.pick(from: puzzles, on: day.adding(days: 4))?.id == "p1")
        #expect(DailyPuzzle.pick(from: puzzles, on: day.adding(days: -1))?.id == "p2")
        #expect(DailyPuzzle.pick(from: puzzles, on: day.adding(days: 3000))?.id == "p0")
        #expect(DailyPuzzle.pick(from: [], on: day) == nil)
        #expect(DailyPuzzle.key(level: .b1, day: day) == "daily-B1-2026-01-01")
        #expect(DailyPuzzle.level(for: .a1, available: [.a2, .b1]) == .a2)
        #expect(DailyPuzzle.level(for: .b2, available: [.a2, .b2]) == .b2)
    }

    // MARK: - Game

    @Test func typingFillsTheActiveWordAndJumpsAhead() {
        var game = CrosswordGame(puzzle: Self.sample)
        #expect(game.activeEntry.id == "1a")
        for ch in "borrow" { game.type(ch) }
        #expect(game.isSolved(game.activeEntry) == false || game.activeEntry.id != "1a")
        #expect(game.isSolved(Self.sample.entries[0]))
        // Solved, so the cursor moved to the next unsolved word (3 Yatay).
        #expect(game.activeEntry.id == "3a")
        #expect(game.solvedCount == 1)
    }

    @Test func lettersUseASCIIUppercase() {
        var game = CrosswordGame(puzzle: Self.sample)
        game.select(GridPoint(3, 0))
        for ch in "hesitate" { game.type(ch) }
        #expect(game.isSolved(Self.sample.entries[2]))
        #expect(game.typed[GridPoint(3, 3)] == "I")
    }

    @Test func deleteAndDirectionToggle() {
        var game = CrosswordGame(puzzle: Self.sample)
        game.type("B"); game.type("Q")
        game.deleteBackward()
        #expect(game.typed[GridPoint(0, 3)] == nil)
        game.deleteBackward()
        #expect(game.typed[GridPoint(0, 2)] == nil)
        // (0,3) is shared by BORROW and OBVIOUS: tapping it twice switches to Dikey.
        game.select(GridPoint(0, 3))
        #expect(game.activeEntry.id == "1a")
        game.select(GridPoint(0, 3))
        #expect(game.activeEntry.id == "2d")
    }

    @Test func hintsMarkWordsHelped() {
        var game = CrosswordGame(puzzle: Self.sample)
        game.select(GridPoint(3, 0))
        game.type("H"); game.type("A")
        let hadError = game.checkWord()
        #expect(hadError)
        #expect(game.wrong == [GridPoint(3, 1)])
        #expect(game.helped == ["3a"])
        game.select(GridPoint(3, 1))
        game.type("E")
        #expect(game.wrong.isEmpty)

        game.step(1)
        #expect(game.activeEntry.id == "5a")
        game.revealLetter()
        #expect(game.revealed.count == 1)
        #expect(game.cursor == GridPoint(9, 2)) // moved past the revealed letter
        game.revealWord()
        #expect(game.isSolved(Self.sample.entries[4]))
        #expect(game.helped == ["3a", "5a"])
        #expect(game.hintsUsed == 3)

        // A clean check isn't help.
        var clean = CrosswordGame(puzzle: Self.sample)
        clean.type("B")
        let cleanError = clean.checkWord()
        #expect(!cleanError)
        #expect(clean.helped.isEmpty)
    }

    /// Types the missing letters of `entry`, the way a player would.
    static func fill(_ entry: CrosswordEntry, in game: inout CrosswordGame) {
        game.focus(entry)
        for (cell, letter) in zip(entry.cells, entry.letters) where game.typed[cell] == nil {
            game.type(letter)
        }
    }

    @Test func completionAndSnapshotRoundTrip() throws {
        var game = CrosswordGame(puzzle: Self.sample)
        for entry in Self.sample.orderedEntries {
            if entry.id == "4d" { game.focus(entry); game.revealWord(); continue }
            Self.fill(entry, in: &game)
        }
        #expect(game.isComplete)
        #expect(game.unaidedEntries.map(\.id) == ["1a", "3a", "5a", "2d"])

        let restored = CrosswordGame(puzzle: Self.sample, snapshot: try CrosswordGame.decodeSnapshot(try game.encodedSnapshot()))
        #expect(restored.isComplete)
        #expect(restored.helped == ["4d"])
        #expect(restored.hintsUsed == 1)
    }

    @Test func storePersistsAndRecordsLearning() throws {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        let clock = AppClock.fixed(Date(timeIntervalSince1970: 1_800_000_000), timeZone: .gmt)
        var game = CrosswordGame(puzzle: Self.sample)
        game.focus(Self.sample.entries[2])
        let helpedEntry = game.revealLetter()
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try PuzzleStore.recordHint(for: helpedEntry, clock: clock, db: db)
            try PuzzleStore.save(key: "k", game: game, seconds: 42, completedAt: nil, db: db)
        }
        let saved = try db.reader.read { db in try PuzzleStore.load(key: "k", puzzle: Self.sample, db: db) }
        #expect(saved.seconds == 42)
        #expect(saved.game.revealed.count == 1)
        #expect(try db.reader.read { db in try LearningStore.state(of: "b2-hesitate", db: db).state } == .struggling)

        var finished = CrosswordGame(puzzle: Self.sample)
        for entry in Self.sample.orderedEntries { Self.fill(entry, in: &finished) }
        #expect(finished.isComplete)
        try db.writer.write { db in try PuzzleStore.recordCompletion(finished, clock: clock, db: db) }
        #expect(try db.reader.read { db in try LearningStore.state(of: "a2-borrow", db: db).state } == .learned)
    }

    @Test func progressSavedForAnotherGridIsIgnored() throws {
        // Regenerated puzzles keep their ids; old letters must not land on the new grid.
        let db = try AppDatabase.inMemory()
        var game = CrosswordGame(puzzle: Self.sample)
        game.focus(Self.sample.entries[0])
        game.revealWord()
        try db.writer.write { db in
            try PuzzleStore.save(key: "k", game: game, seconds: 90, completedAt: nil, db: db)
        }
        var moved = Self.sample
        moved.entries[0].answer = String(moved.entries[0].answer.reversed())
        let other = try db.reader.read { db in try PuzzleStore.load(key: "k", puzzle: moved, db: db) }
        #expect(other.game.typed.isEmpty && other.game.revealed.isEmpty && other.seconds == 0)
        let same = try db.reader.read { db in try PuzzleStore.load(key: "k", puzzle: Self.sample, db: db) }
        #expect(same.game.revealed.count == Self.sample.entries[0].length && same.seconds == 90)

        // Saves from before the fingerprint existed start over too.
        try db.writer.write { db in
            try db.execute(sql: "UPDATE puzzle_progress SET cells = ? WHERE puzzle_key = 'k'",
                           arguments: [#"{"typed":{"0,0":"X"},"revealed":["0,0"],"wrong":[],"helped":[],"hintsUsed":1}"#])
        }
        let legacy = try db.reader.read { db in try PuzzleStore.load(key: "k", puzzle: Self.sample, db: db) }
        #expect(legacy.game.typed.isEmpty)

        try db.writer.write { db in try PuzzleStore.reset(key: "k", db: db) }
        #expect(try db.reader.read { db in try PuzzleProgress.fetchCount(db) } == 0)
    }

    // MARK: - Generator

    @Test func generatorSkipsWordsWithTheSameMeaning() throws {
        // develop and improve are both "geliştirmek": they must never share a grid.
        let cards = try Self.cards()
        let develop = CrosswordGenerator.Word(card: try #require(cards["b1-develop"]))
        let improve = CrosswordGenerator.Word(card: try #require(cards["b1-improve"]))
        #expect(!develop.meanings.isDisjoint(with: improve.meanings))
        let fillers = cards.values.filter { $0.level == .b1 && $0.word.count <= 10 }.sorted { $0.id < $1.id }.map(CrosswordGenerator.Word.init(card:))
        for seed in UInt64(0)..<200 {
            let puzzle = try #require(CrosswordGenerator.generate(id: "x", seeds: [develop, improve], fillers: fillers, seed: seed))
            let ids = Set(puzzle.entries.map(\.cardID))
            #expect(!(ids.contains("b1-develop") && ids.contains("b1-improve")))
        }
    }

    @Test func generatorIsDeterministicAndValid() throws {
        let words = try Self.cards().values
            .filter { $0.level == .b1 && $0.word.count <= 10 }
            .sorted { $0.id < $1.id }
            .map(CrosswordGenerator.Word.init(card:))
        let seeds = Array(words.prefix(4))
        let a = CrosswordGenerator.generate(id: "x", seeds: seeds, fillers: words, seed: 99)
        let b = CrosswordGenerator.generate(id: "x", seeds: seeds, fillers: words, seed: 99)
        let puzzle = try #require(a)
        #expect(a == b)
        #expect(CrosswordValidator.problems(puzzle).isEmpty)
        #expect(puzzle.entries.count >= 6)
        #expect(Set(seeds.map(\.cardID)).isSubset(of: Set(puzzle.entries.map(\.cardID))))
    }

    /// 10,000 randomized personal generations: all valid, at least 90% place all 4 seeds,
    /// and every one succeeds once the fallback is allowed.
    @Test func tenThousandPersonalGenerations() throws {
        let all = try Self.cards().values
            .filter { $0.isSingleWord && $0.word.count <= 10 }
            .sorted { $0.id < $1.id }
            .map(CrosswordGenerator.Word.init(card:))
        let meaningsByID = Dictionary(uniqueKeysWithValues: all.map { ($0.cardID, $0.meanings) })
        var rng = SeededGenerator(seed: 2026)
        var withFourSeeds = 0
        let runs = 10_000
        let start = Date()
        for run in 0..<runs {
            let pool = all.shuffled(using: &rng)
            let seeds = Array(pool.prefix(4))
            let fillers = Array(pool.dropFirst(4).prefix(80))
            let puzzle = try #require(
                CrosswordGenerator.generate(id: "p\(run)", seeds: seeds, fillers: fillers, seed: UInt64(run)),
                "run \(run) failed even with the fallback"
            )
            #expect(CrosswordValidator.isValid(puzzle), "run \(run) produced an invalid grid")
            #expect(puzzle.width <= 10 && puzzle.height <= 10 && puzzle.entries.count >= 6)
            let meanings = puzzle.entries.map { meaningsByID[$0.cardID] ?? [] }
            #expect(meanings.reduce(0) { $0 + $1.count } == Set(meanings.flatMap { $0 }).count, "run \(run) repeats a clue")
            if Set(seeds.map(\.cardID)).isSubset(of: Set(puzzle.entries.map(\.cardID))) {
                withFourSeeds += 1
            }
        }
        let rate = Double(withFourSeeds) / Double(runs)
        print("Personal puzzles with all 4 seeds: \(Int(rate * 100))%, \(Int(Date().timeIntervalSince(start) / Double(runs) * 1000_000)) µs each")
        #expect(rate >= 0.9)
    }
}
