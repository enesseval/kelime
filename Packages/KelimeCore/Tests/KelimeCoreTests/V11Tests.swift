import Foundation
import GRDB
import Testing
@testable import KelimeCore

/// 1.1: streak, weekly summary, game pool, Kelime Avı and Eşleştir.
struct V11Tests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    let start = try! Date("2026-11-04T09:00:00Z", strategy: .iso8601) // a Wednesday

    func clock(days: Int = 0) -> AppClock {
        .fixed(start.addingTimeInterval(Double(days) * 86_400), timeZone: istanbul)
    }

    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        return db
    }

    func d(_ s: String) -> LocalDate { LocalDate(string: s)! }

    // MARK: Streak

    @Test func streakCountsDaysInARow() {
        let days: Set = [d("2026-11-02"), d("2026-11-03"), d("2026-11-04")]
        let s = Streak.compute(days: days, today: d("2026-11-04"), freezesPerWeek: 1)
        #expect(s.current == 3 && s.studiedToday && !s.atRisk && s.frozenDays.isEmpty)
    }

    @Test func todayWithoutStudyIsAtRiskNotBroken() {
        let days: Set = [d("2026-11-02"), d("2026-11-03")]
        let s = Streak.compute(days: days, today: d("2026-11-04"), freezesPerWeek: 1)
        #expect(s.current == 2 && s.atRisk && !s.studiedToday)
    }

    @Test func oneMissedDayIsFrozenOncePerWeek() {
        // Mon, (Tue missed), Wed, Thu
        let days: Set = [d("2026-11-02"), d("2026-11-04"), d("2026-11-05")]
        let s = Streak.compute(days: days, today: d("2026-11-05"), freezesPerWeek: 1)
        #expect(s.current == 3)
        #expect(s.frozenDays == [d("2026-11-03")])

        // A second gap in the same week breaks it with one freeze, holds with two. The freeze
        // goes to the first gap (Tuesday), so Thursday ends the streak.
        let two: Set = [d("2026-11-02"), d("2026-11-04"), d("2026-11-06")]
        #expect(Streak.compute(days: two, today: d("2026-11-06"), freezesPerWeek: 1).current == 1)
        #expect(Streak.compute(days: two, today: d("2026-11-06"), freezesPerWeek: 2).current == 3)
    }

    /// Same as Android's StreakTest: the morning after a missed day the streak is at risk, not 0.
    @Test func yesterdayMissedIsFrozenWhileTodayIsOpen() {
        let days: Set = [d("2026-11-02"), d("2026-11-03")]
        let s = Streak.compute(days: days, today: d("2026-11-05"), freezesPerWeek: 1)
        #expect(s.current == 2 && s.atRisk)
        #expect(s.frozenDays == [d("2026-11-04")])
    }

    @Test func freezesRenewEveryMonday() {
        // Gap on Sun 1 Nov (week of 26 Oct) and on Tue 3 Nov (week of 2 Nov): one freeze each.
        let days: Set = [d("2026-10-31"), d("2026-11-02"), d("2026-11-04"), d("2026-11-05")]
        #expect(Streak.compute(days: days, today: d("2026-11-05"), freezesPerWeek: 1).current == 4)
    }

    /// The longest streak follows the learner's own plan: one freeze a week when free.
    @Test func longestStreakUsesTheFreePlanFreezes() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            // Mon, (Tue), Wed, (Thu), Fri: one freeze covers Tuesday, Thursday ends it.
            for day in ["2026-11-02", "2026-11-04", "2026-11-06"] { try Streak.record(.quickReview, on: d(day), db: db) }
            #expect(try Settings.int(.longestStreak, in: db) == 2)
        }
    }

    @Test func twoMissedDaysInARowEndTheStreak() {
        let days: Set = [d("2026-11-01"), d("2026-11-04")]
        #expect(Streak.compute(days: days, today: d("2026-11-04"), freezesPerWeek: 2).current == 1)
    }

    @Test func recordingKeepsSourcesAndLongest() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try Streak.record(.quickReview, on: d("2026-11-03"), db: db)
            try Streak.record(.puzzle, on: d("2026-11-04"), db: db)
            try Streak.record(.match, on: d("2026-11-04"), db: db)
        }
        let status = try db.reader.read { db in try Streak.status(db: db, clock: clock()) }
        #expect(status.current == 2 && status.longest == 2)
        let sources = try db.reader.read { db in try String.fetchOne(db, sql: "SELECT sources FROM streak_day WHERE day = '2026-11-04'") }
        #expect(sources == "match,puzzle")
    }

    // MARK: Weekly summary

    @Test func weeklySummaryCountsLastWeek() throws {
        let db = try makeDatabase()
        let lastWeek = clock(days: -7) // Wednesday of the previous week
        try db.writer.write { db in
            try LearningStore.record(.answered(correct: false), cardID: "b1-curious", source: .quickReview, clock: lastWeek, db: db)
            try LearningStore.record(.answered(correct: true), cardID: "b1-curious", source: .quickReview, clock: clock(days: -6), db: db)
            try LearningStore.record(.answered(correct: true), cardID: "b1-curious", source: .quickReview, clock: clock(days: -5), db: db)
            try db.execute(sql: "INSERT INTO shown_log (day, card_id) VALUES ('2026-10-28', 'a'), ('2026-10-29', 'b')")
            try Streak.record(.quickReview, on: lastWeek.today, db: db)
        }
        let summary = try db.reader.read { db in try WeeklySummary.lastWeek(db: db, clock: clock()) }
        #expect(summary.weekStart == d("2026-10-26"))
        #expect(summary.learned == 1)
        #expect(summary.answers == 3 && summary.correct == 2)
        #expect(summary.widgetWords == 2)
        #expect(summary.wordOfTheWeek?.id == "b1-curious")
        #expect(try db.reader.read { db in try WeeklySummary.isNew(db: db, clock: clock()) })
        try db.writer.write { db in try WeeklySummary.markSeen(db: db, clock: clock()) }
        #expect(try db.reader.read { db in try WeeklySummary.isNew(db: db, clock: clock()) } == false)
    }

    // MARK: Games

    @Test func poolGivesDistinctPlainWords() throws {
        let db = try makeDatabase()
        var rng = SeededGenerator(seed: 4)
        let cards = try db.reader.read { db in
            try GamePool.cards(count: 12, singleWords: true, lengths: 3...8, db: db, today: clock().today, using: &rng)
        }
        #expect(cards.count == 12)
        #expect(Set(cards.map { $0.word.lowercased() }).count == 12)
        #expect(cards.allSatisfy { $0.isSingleWord && (3...8).contains($0.word.count) })
    }

    @Test func wordSearchPlacesWordsInStraightLines() throws {
        let db = try makeDatabase()
        var rng = SeededGenerator(seed: 9)
        let cards = try db.reader.read { db in
            try GamePool.cards(count: 20, singleWords: true, lengths: 3...8, db: db, today: clock().today, using: &rng)
        }
        let game = try #require(WordSearch.make(cards: cards, size: 8, wordCount: 6, using: &rng))
        #expect(game.placements.count == 6)
        for p in game.placements {
            let read = String(p.cells.map { game.letter(at: $0) })
            #expect(read == String(p.letters))
            #expect(p.cells.allSatisfy { $0.row < 8 && $0.col < 8 })
            #expect(game.placement(matching: p.cells.reversed())?.id == p.id)
            #expect(game.placement(spelledBy: p.cells)?.id == p.id)
            #expect(game.placement(spelledBy: p.cells, skip: [p.id])?.id != p.id)
        }
        #expect(game.grid.allSatisfy { $0.count == 8 && $0.allSatisfy { $0.isASCII && $0.isUppercase } })
    }

    @Test func dragLinesAreStraight() {
        let a = WordSearch.Point(row: 1, col: 1)
        #expect(WordSearch.line(from: a, to: .init(row: 1, col: 4))?.count == 4)
        #expect(WordSearch.line(from: a, to: .init(row: 4, col: 4))?.count == 4)
        #expect(WordSearch.line(from: a, to: .init(row: 3, col: 4)) == nil)
    }

    func matchCard(_ i: Int) -> Card {
        Card(id: "c\(i)", word: "word\(i)", pos: .noun, level: .a1, tr: ["anlam\(i)"], exampleEN: "", exampleTR: "")
    }

    @Test func matchGameScoresAndMisses() {
        var game = MatchGame(cards: (0..<7).map(matchCard), seed: 1)
        let en1 = game.english.compactMap { $0 }.first { $0.card.id == "c1" }!
        let tr0 = game.turkish.compactMap { $0 }.first { $0.card.id == "c0" }!
        let en0 = game.english.compactMap { $0 }.first { $0.card.id == "c0" }!
        #expect(game.tap(en1) == nil)
        #expect(game.tap(tr0) == .miss(english: matchCard(1), turkish: matchCard(0)))
        #expect(game.tap(en0) == nil)
        #expect(game.tap(tr0) == .match(matchCard(0)))
        #expect(game.score == 1)
        #expect(game.firstTry.map(\.id) == ["c0"])
        #expect(game.missed.map(\.id) == ["c1"])
    }

    @Test func noPairStartsOnTheSameRow() {
        for seed in 0..<200 {
            let game = MatchGame(cards: (0..<10).map(matchCard), seed: UInt64(seed))
            for i in game.english.indices {
                #expect(game.english[i]?.card.id != game.turkish[i]?.card.id, "seed \(seed)")
            }
        }
    }

    /// The bug from testing: a matched slot was refilled at once, so the newest cards were
    /// easy to spot. Now matched slots stay empty until three pairs are gone, then the next
    /// three cards land in random empty slots, never with a card's halves on one row.
    @Test func matchedSlotsRefillInBatches() {
        for seed in 0..<50 {
            var game = MatchGame(cards: (0..<30).map(matchCard), seed: UInt64(seed))
            var rounds = 0
            while !game.isOutOfCards && rounds < 200 {
                rounds += 1
                guard let en = game.english.compactMap({ $0 }).first(where: { tile in
                          game.turkish.contains { $0?.card.id == tile.card.id }
                      }),
                      let tr = game.turkish.compactMap({ $0 }).first(where: { $0.card.id == en.card.id })
                else { break }
                let before = Set(game.english.compactMap { $0?.card.id })
                game.tap(en)
                #expect(game.tap(tr) == .match(en.card))
                let empty = game.english.filter { $0 == nil }.count
                #expect(empty < MatchGame.refillAt || game.score > 25, "seed \(seed) round \(rounds)")
                for i in game.english.indices {
                    guard let card = game.english[i]?.card, !before.contains(card.id) else { continue }
                    #expect(game.turkish[i]?.card.id != card.id, "seed \(seed) round \(rounds)")
                }
            }
            #expect(game.score == 30, "seed \(seed)")
            #expect(game.isOutOfCards)
        }
    }
}
