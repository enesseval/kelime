import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct CoursePuzzleTests {
    let clock = AppClock.fixed(try! Date("2026-10-19T07:20:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "Europe/Istanbul")!)

    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try Preferences(level: .a1, enabledDecks: [.a1]).save(db)
        }
        return db
    }

    func startedCardIDs(_ db: Database) throws -> Set<String> {
        var ids = Set<String>()
        for unit in try Curriculum.started(db: db) { ids.formUnion(try Curriculum.cards(of: unit, db: db).map(\.id)) }
        return ids
    }

    @Test func usesStartedUnitsWithStrugglingWordsFirst() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try Curriculum.start("a1-cafe", db: db)
            for id in ["a1-coffee", "a1-milk", "a1-water"] {
                try CardState(cardID: id, state: .struggling).save(db)
            }
        }
        for offset in 0..<20 {
            let day = clock.today.adding(days: offset)
            let puzzle = try #require(try db.reader.read { db in try CoursePuzzle.daily(level: .a1, day: day, db: db) })
            let ids = Set(puzzle.entries.map(\.cardID))
            #expect(ids.isSubset(of: try db.reader.read { db in try startedCardIDs(db) }))
            #expect(CrosswordValidator.isValid(puzzle))
            #expect(ids.isSuperset(of: ["a1-coffee", "a1-milk", "a1-water"]), "day \(offset): \(ids)")
        }
    }

    @Test func todaysGridIsKeptWhileWordsChange() throws {
        let db = try makeDatabase()
        try db.writer.write { db in try CoursePuzzle.keepToday(clock: clock, db: db) }
        let before = try db.reader.read { db in try CoursePuzzle.daily(level: .a1, day: clock.today, db: db) }
        try db.writer.write { db in
            try Curriculum.start("a1-home", db: db)
            try CardState(cardID: "a1-house", state: .struggling).save(db)
            try CoursePuzzle.keepToday(clock: clock, db: db)
        }
        let after = try db.reader.read { db in try CoursePuzzle.daily(level: .a1, day: clock.today, db: db) }
        #expect(before != nil && before == after)
    }

    @Test func levelsWithoutUnitsKeepNoGrid() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try Preferences(level: .b2).save(db)
            try CoursePuzzle.keepToday(clock: clock, db: db)
        }
        #expect(try db.reader.read { db in try PuzzleProgress.fetchCount(db) } == 0)
    }
}
