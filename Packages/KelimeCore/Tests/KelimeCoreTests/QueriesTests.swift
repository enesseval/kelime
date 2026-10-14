import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct QueriesTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    // Wednesday 2026-10-14, 12:00 in Istanbul.
    var clock: AppClock { .fixed(try! Date("2026-10-14T09:00:00Z", strategy: .iso8601), timeZone: istanbul) }

    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        return db
    }

    func clock(daysAgo: Int) -> AppClock {
        .fixed(clock.now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)), timeZone: istanbul)
    }

    @Test func weekStartsOnMonday() {
        #expect(StatsQueries.weekStart(for: LocalDate(year: 2026, month: 10, day: 14)).string == "2026-10-12")
        #expect(StatsQueries.weekStart(for: LocalDate(year: 2026, month: 10, day: 12)).string == "2026-10-12")
        #expect(StatsQueries.weekStart(for: LocalDate(year: 2026, month: 10, day: 18)).string == "2026-10-12")
        #expect(StatsQueries.weekStart(for: LocalDate(year: 2026, month: 11, day: 1)).string == "2026-10-26")
    }

    @Test func weekStatsCountThisWeekOnly() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try LearningStore.record(.answered(correct: true), cardID: "a2-borrow", source: .quickReview, clock: clock, db: db)
            try LearningStore.record(.markedKnown, cardID: "b1-reliable", source: .wordDetail, clock: clock(daysAgo: 2), db: db)
            // Last Sunday is outside this week.
            try LearningStore.record(.answered(correct: true), cardID: "a2-busy", source: .quickReview, clock: clock(daysAgo: 3), db: db)
            try LearningStore.record(.answered(correct: false), cardID: "b2-reluctant", source: .quickReview, clock: clock, db: db)
        }
        let stats = try db.reader.read { db in try StatsQueries.week(db: db, clock: clock) }
        #expect(stats.learnedThisWeek == 2)
        #expect(stats.strugglingNow == 1)
        #expect(stats.days.map(\.initial) == ["P", "S", "Ç", "P", "C", "C", "P"])
        #expect(stats.days.map(\.reviewed) == [false, false, true, false, false, false, false])
    }

    @Test func examCountdown() {
        #expect(StatsQueries.daysUntilExam(LocalDate(year: 2026, month: 11, day: 16), clock: clock) == 33)
        #expect(StatsQueries.daysUntilExam(LocalDate(year: 2026, month: 10, day: 14), clock: clock) == 0)
        #expect(StatsQueries.daysUntilExam(LocalDate(year: 2026, month: 10, day: 1), clock: clock) == nil)
        #expect(StatsQueries.daysUntilExam(nil, clock: clock) == nil)
    }

    @Test func quickReviewAllowance() throws {
        let db = try makeDatabase()
        #expect(try db.reader.read { db in try QuickReviewLimit.remaining(db: db, clock: clock) } == 1)
        try db.writer.write { db in
            try LearningStore.record(.answered(correct: true), cardID: "a2-borrow", source: .quickReview, clock: clock, sessionID: "s1", db: db)
            try LearningStore.record(.answered(correct: true), cardID: "a2-busy", source: .quickReview, clock: clock, sessionID: "s1", db: db)
            // Widget answers and yesterday's sessions don't count.
            try LearningStore.record(.answered(correct: true), cardID: "a2-wait", source: .widget, clock: clock, db: db)
            try LearningStore.record(.answered(correct: true), cardID: "a2-wait", source: .quickReview, clock: clock(daysAgo: 1), sessionID: "s0", db: db)
        }
        try db.reader.read { db throws in
            #expect(try QuickReviewLimit.sessionsToday(db: db, clock: clock) == 1)
            #expect(try QuickReviewLimit.remaining(db: db, clock: clock) == 0)
        }
        try db.writer.write { db in try Settings.set(.isPro, true, in: db) }
        #expect(try db.reader.read { db in try QuickReviewLimit.remaining(db: db, clock: clock) } == nil)
    }

    @Test func wordListSegmentsAndSearch() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try LearningStore.record(.markedStruggling, cardID: "b2-reluctant", source: .wordDetail, clock: clock, db: db)
            try LearningStore.record(.markedKnown, cardID: "b1-reliable", source: .wordDetail, clock: clock, db: db)
            try LearningStore.setFavorite(true, cardID: "a2-borrow", db: db)
        }
        try db.reader.read { db throws in
            #expect(try WordQueries.list(segment: .struggling, db: db).map(\.id) == ["b2-reluctant"])
            #expect(try WordQueries.list(segment: .learned, db: db).map(\.id) == ["b1-reliable"])
            #expect(try WordQueries.list(segment: .favorites, db: db).map(\.id) == ["a2-borrow"])
            let all = try WordQueries.list(segment: .all, db: db)
            #expect(all.count == 202)
            #expect(all.map(\.card.word) == all.map(\.card.word).sorted())
            // English word, Turkish meaning, Turkish casing and missing diacritics.
            #expect(try WordQueries.list(segment: .all, search: "relu", db: db).map(\.id) == ["b2-reluctant"])
            #expect(try WordQueries.list(segment: .all, search: "GÜVENİLİR", db: db).map(\.id) == ["b1-reliable"])
            #expect(try WordQueries.list(segment: .all, search: "isteksiz", db: db).map(\.id) == ["b2-reluctant"])
            #expect(try WordQueries.list(segment: .all, search: "odunc", db: db).map(\.id) == ["a2-borrow"])
            #expect(try WordQueries.list(segment: .struggling, search: "borrow", db: db).isEmpty)
        }
    }

    @Test func wordItemDetails() throws {
        let db = try makeDatabase()
        try db.reader.read { db throws in
            let yds = try #require(try WordQueries.item(id: "b2-significant", db: db))
            #expect(yds.deckLabel == "YDS")
            #expect(yds.state == .new && !yds.favorite)
            #expect(try WordQueries.item(id: "a2-borrow", db: db)?.deckLabel == "Genel")
            #expect(try WordQueries.item(id: "missing", db: db) == nil)
        }
    }

    @Test func deckProgressAndToggles() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try LearningStore.record(.markedKnown, cardID: "a2-borrow", source: .wordDetail, clock: clock, db: db)
        }
        let progress = try db.reader.read { db in try DeckQueries.progress(db: db) }
        let byID = Dictionary(uniqueKeysWithValues: progress.map { ($0.deck, $0) })
        #expect(progress.map(\.deck) == DeckID.allCases)
        #expect(byID[.a2]?.total == 51 && byID[.a2]?.learned == 1)
        #expect(byID[.a1]?.total == 0)
        #expect(byID[.yds]?.total == 71 && byID[.yds]?.locked == true)
        #expect(byID[.b1]?.enabled == true && byID[.b1]?.locked == false)

        let changedLocked = try db.writer.write { db in try DeckQueries.setEnabled(true, deck: .yds, db: db) }
        #expect(!changedLocked)
        try db.writer.write { db in try DeckQueries.setEnabled(false, deck: .a2, db: db) }
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks } == [.b1])
        try db.writer.write { db in
            try Settings.set(.isPro, true, in: db)
            try DeckQueries.setEnabled(true, deck: .yds, db: db)
        }
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks } == [.b1, .yds])
    }
}
