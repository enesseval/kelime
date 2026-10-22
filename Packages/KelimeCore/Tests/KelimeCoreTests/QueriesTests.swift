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
            try LearningStore.record(.answered(correct: true), cardID: "b1-curious", source: .quickReview, clock: clock, db: db)
            try LearningStore.record(.markedKnown, cardID: "b1-reliable", source: .wordDetail, clock: clock(daysAgo: 2), db: db)
            // Last Sunday is outside this week.
            try LearningStore.record(.answered(correct: true), cardID: "b1-honest", source: .quickReview, clock: clock(daysAgo: 3), db: db)
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

    @Test func streakCountsDaysInARow() throws {
        let db = try makeDatabase()
        #expect(try db.reader.read { db in try StatsQueries.streak(db: db, clock: clock) } == 0)
        try db.writer.write { db in
            for daysAgo in [1, 2, 3, 5] {
                try LearningStore.record(.answered(correct: true), cardID: "b1-curious", source: .widget, clock: clock(daysAgo: daysAgo), db: db)
            }
        }
        // Today is still open: yesterday's run of three counts.
        #expect(try db.reader.read { db in try StatsQueries.streak(db: db, clock: clock) } == 3)
        try db.writer.write { db in
            try LearningStore.record(.answered(correct: true), cardID: "b1-honest", source: .quickReview, clock: clock, db: db)
        }
        #expect(try db.reader.read { db in try StatsQueries.week(db: db, clock: clock).streak } == 4)
    }

    @Test func wordListSegmentsAndSearch() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try LearningStore.record(.markedStruggling, cardID: "b2-reluctant", source: .wordDetail, clock: clock, db: db)
            try LearningStore.record(.markedKnown, cardID: "b1-reliable", source: .wordDetail, clock: clock, db: db)
            try LearningStore.setFavorite(true, cardID: "b1-curious", db: db)
        }
        try db.reader.read { db throws in
            #expect(try WordQueries.list(segment: .struggling, db: db).map(\.id) == ["b2-reluctant"])
            #expect(try WordQueries.list(segment: .learned, db: db).map(\.id) == ["b1-reliable"])
            #expect(try WordQueries.list(segment: .favorites, db: db).map(\.id) == ["b1-curious"])
            let all = try WordQueries.list(segment: .all, db: db)
            // The B1 core (started) and the three words with progress; no other unit, no exam card.
            let core = try Curriculum.cards(of: "b1-core", db: db).map(\.id)
            #expect(Set(all.map(\.id)) == Set(core).union(["b2-reluctant", "b1-reliable", "b1-curious"]))
            let words = all.map { $0.card.word.lowercased() }
            #expect(words == words.sorted())
            // English word, Turkish meaning, Turkish casing and missing diacritics.
            #expect(try WordQueries.list(segment: .all, search: "relu", db: db).map(\.id) == ["b2-reluctant"])
            #expect(try WordQueries.list(segment: .all, search: "GÜVENİLİR", db: db).map(\.id).contains("b1-reliable"))
            #expect(try WordQueries.list(segment: .all, search: "isteksiz", db: db).map(\.id) == ["b2-reluctant"])
            #expect(try WordQueries.list(segment: .all, search: "merakli", db: db).map(\.id) == ["b1-curious"])
            #expect(try WordQueries.list(segment: .struggling, search: "curious", db: db).isEmpty)
        }
        // Starting a unit brings its words in.
        try db.writer.write { db in try Curriculum.start("b1-career", db: db) }
        let career = try db.reader.read { db in try Curriculum.cards(of: "b1-career", db: db).map(\.id) }
        let all = try db.reader.read { db in try WordQueries.list(segment: .all, db: db).map(\.id) }
        #expect(Set(career).isSubset(of: Set(all)))
    }

    @Test func wordListFiltersAndSorts() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try LearningStore.record(.answered(correct: false), cardID: "b2-reluctant", source: .quickReview, clock: clock(daysAgo: 1), db: db)
            try LearningStore.record(.answered(correct: false), cardID: "b2-reluctant", source: .quickReview, clock: clock, db: db)
            try LearningStore.record(.answered(correct: false), cardID: "b1-honest", source: .quickReview, clock: clock(daysAgo: 1), db: db)
        }
        try db.reader.read { db throws in
            let b2 = try WordQueries.list(segment: .all, filter: WordFilter(levels: [.b2]), db: db)
            #expect(b2.map(\.id) == ["b2-reluctant"])
            let struggling = try WordQueries.list(segment: .all, filter: WordFilter(states: [.struggling]), db: db)
            #expect(Set(struggling.map(\.id)) == ["b2-reluctant", "b1-honest"])
            let verbs = try WordQueries.list(segment: .all, filter: WordFilter(kinds: [.verb]), db: db)
            #expect(!verbs.isEmpty && verbs.allSatisfy { $0.card.pos == .verb })
            let fresh = try WordQueries.list(segment: .all, filter: WordFilter(states: [.new]), db: db)
            #expect(!fresh.isEmpty && fresh.allSatisfy { $0.state == .new })

            let missed = try WordQueries.list(segment: .all, sort: .mostMissed, db: db)
            #expect(missed.prefix(2).map(\.id) == ["b2-reluctant", "b1-honest"])
            let recent = try WordQueries.list(segment: .all, sort: .recentlyStudied, db: db)
            #expect(recent.first?.id == "b2-reluctant")
            let reverse = try WordQueries.list(segment: .all, sort: .reverseAlphabetical, db: db).map { $0.card.word.lowercased() }
            #expect(reverse == reverse.sorted(by: >))
            let byLevel = try WordQueries.list(segment: .all, sort: .level, db: db).map(\.card.level)
            #expect(byLevel == byLevel.sorted())
        }
    }

    @Test func wordItemDetails() throws {
        let db = try makeDatabase()
        try db.reader.read { db throws in
            let yds = try #require(try WordQueries.item(id: "b2-significant", db: db))
            #expect(yds.deckLabel == "YDS")
            #expect(yds.state == .new && !yds.favorite)
            #expect(try WordQueries.item(id: "b1-curious", db: db)?.deckLabel == "Genel")
            #expect(try WordQueries.item(id: "missing", db: db) == nil)
        }
    }

    @Test func deckProgressAndToggles() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try LearningStore.record(.markedKnown, cardID: "b1-curious", source: .wordDetail, clock: clock, db: db)
        }
        let progress = try db.reader.read { db in try DeckQueries.progress(db: db) }
        let byID = Dictionary(uniqueKeysWithValues: progress.map { ($0.deck, $0) })
        #expect(progress.map(\.deck) == DeckID.allCases)
        #expect(byID[.a2]?.total == 356 && byID[.b1]?.learned == 1)
        #expect(byID[.a1]?.total == 285 && byID[.a1]?.enabled == false)
        #expect(byID[.yds]?.total == 355)
        #expect(byID[.b1]?.enabled == true)

        try db.writer.write { db in try DeckQueries.setEnabled(false, deck: .a2, db: db) }
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks } == [.b1])
        // Every deck is free: exam decks switch on without Pro.
        try db.writer.write { db in try DeckQueries.setEnabled(true, deck: .yds, db: db) }
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks } == [.b1, .yds])
    }
}
