import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct DatabaseTests {
    @Test func migrationCreatesAllTables() throws {
        let db = try AppDatabase.inMemory()
        let tables = try db.reader.read { db throws in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'")
        }
        #expect(Set(tables) == ["card", "card_deck", "card_state", "widget_queue", "settings", "review_log", "puzzle_progress"])
    }

    @Test func sharedPoolUsesWAL() throws {
        let dir = try TestSupport.temporaryDirectory()
        let db = try AppDatabase.open(at: dir.appendingPathComponent("test.sqlite"))
        let mode = try db.reader.read { db in try String.fetchOne(db, sql: "PRAGMA journal_mode") }
        #expect(mode == "wal")
    }

    @Test func twoConnectionsSeeEachOthersWrites() throws {
        // Stand-in for app + widget extension opening the same file.
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("shared.sqlite")
        let app = try AppDatabase.open(at: url)
        let widget = try AppDatabase.open(at: url)
        try app.writer.write { db in try Settings.set(.isPro, true, in: db) }
        #expect(try widget.reader.read { db in try Settings.bool(.isPro, in: db) })
        try widget.writer.write { db in try CardState(cardID: "b2-reluctant", state: .learned).insert(db) }
        #expect(try app.reader.read { db in try CardState.fetchOne(db, key: "b2-reluctant")?.state } == .learned)
    }

    @Test func settingsRoundTrip() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try Settings.set(.level, "B1", in: db)
            try Settings.set(.rotationInterval, 180, in: db)
            try Settings.set(.onboardingDone, true, in: db)
            try Settings.set(.examDate, LocalDate(year: 2026, month: 11, day: 16), in: db)
        }
        try db.reader.read { db throws in
            #expect(try Settings.string(.level, in: db) == "B1")
            #expect(try Settings.int(.rotationInterval, in: db) == 180)
            #expect(try Settings.bool(.onboardingDone, in: db))
            #expect(try Settings.bool(.isPro, in: db) == false)
            #expect(try Settings.date(.examDate, in: db)?.string == "2026-11-16")
        }
        try db.writer.write { db in try Settings.set(.examDate, nil as LocalDate?, in: db) }
        #expect(try db.reader.read { db in try Settings.date(.examDate, in: db) } == nil)
    }

    @Test func userRecordsRoundTrip() throws {
        let db = try AppDatabase.inMemory()
        let slot = Date(timeIntervalSince1970: 1_800_000_000)
        try db.writer.write { db in
            try CardState(cardID: "x", state: .struggling, correctStreak: 1, lastAnsweredOn: LocalDate(year: 2026, month: 10, day: 13), favorite: true).insert(db)
            try WidgetQueueEntry(slotStart: slot, cardID: "x", quizOptions: ["reluctant", "reliable"]).insert(db)
            var log = ReviewLog(cardID: "x", answeredAt: slot, answeredOn: LocalDate(year: 2026, month: 10, day: 13), correct: false, source: .quickReview)
            try log.insert(db)
            #expect(log.id != nil)
            try PuzzleProgress(puzzleKey: "daily-B1-2026-10-13", cells: "[]", hintsUsed: 2).insert(db)
        }
        try db.reader.read { db throws in
            let state = try #require(try CardState.fetchOne(db, key: "x"))
            #expect(state.state == .struggling && state.favorite && state.lastAnsweredOn?.string == "2026-10-13")
            #expect(try WidgetQueueEntry.fetchOne(db, key: slot)?.quizOptions == ["reluctant", "reliable"])
            #expect(try ReviewLog.fetchCount(db) == 1)
            #expect(try PuzzleProgress.fetchOne(db, key: "daily-B1-2026-10-13")?.hintsUsed == 2)
        }
    }
}
