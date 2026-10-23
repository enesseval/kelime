import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct LearningRulesTests {
    let day1 = LocalDate(year: 2026, month: 10, day: 13)
    var day2: LocalDate { day1.adding(days: 1) }
    var day3: LocalDate { day1.adding(days: 2) }

    func apply(_ events: [(LearningEvent, LocalDate)], from start: CardState = CardState(cardID: "x")) -> CardState {
        events.reduce(start) { LearningRules.apply($1.0, to: $0, on: $1.1) }
    }

    @Test(arguments: [LearningState.new, .struggling, .learned])
    func wrongAnswerMakesStruggling(_ from: LearningState) {
        let s = apply([(.answered(correct: false), day1)], from: CardState(cardID: "x", state: from, correctStreak: 1))
        #expect(s.state == .struggling)
        #expect(s.correctStreak == 0)
        #expect(s.lastAnsweredOn == day1)
    }

    @Test func hintMakesStrugglingWithoutCountingAsAnswer() {
        let s = apply([(.hintUsed, day1)], from: CardState(cardID: "x", state: .learned, correctStreak: 3, lastAnsweredOn: day1.adding(days: -5)))
        #expect(s.state == .struggling)
        #expect(s.correctStreak == 0)
        #expect(s.lastAnsweredOn == day1.adding(days: -5))
    }

    @Test func correctOnNewIsLearned() {
        #expect(apply([(.answered(correct: true), day1)]).state == .learned)
    }

    @Test func correctOnLearnedStaysLearned() {
        let s = apply([(.answered(correct: true), day1)], from: CardState(cardID: "x", state: .learned))
        #expect(s.state == .learned)
    }

    @Test func learnedWordsComeBackAtGrowingIntervals() {
        // Learned on day 1 (streak 1): due after 3 days; each correct review steps up once a day.
        var s = apply([(.answered(correct: true), day1)])
        #expect(SpacedReview.dueDate(s) == day1.adding(days: 3))
        #expect(!SpacedReview.isDue(s, on: day1.adding(days: 2)))
        #expect(SpacedReview.isDue(s, on: day1.adding(days: 3)))
        s = apply([(.answered(correct: true), day1.adding(days: 3)), (.answered(correct: true), day1.adding(days: 3))], from: s)
        #expect(s.correctStreak == 2)
        #expect(SpacedReview.dueDate(s) == day1.adding(days: 10))
        #expect((1...7).map { SpacedReview.interval(streak: $0) } == [3, 7, 21, 60, 120, 120, 120])
        // A wrong answer brings it back to struggling, with no review date.
        s = apply([(.answered(correct: false), day1.adding(days: 10))], from: s)
        #expect(s.state == .struggling && SpacedReview.dueDate(s) == nil)
        // Marking a word known starts its reviews too.
        #expect(SpacedReview.dueDate(apply([(.markedKnown, day1)])) == day1.adding(days: 3))
    }

    @Test func dueWordsWeighMoreThanOtherLearnedWords() {
        let now = Date()
        #expect(WidgetScheduler.weight(SchedulerCandidate(cardID: "a", state: .learned, lastShownAt: now, due: true), now: now) == 2)
        #expect(WidgetScheduler.weight(SchedulerCandidate(cardID: "b", state: .learned, lastShownAt: now), now: now) == 0)
    }

    @Test func twoCorrectSameDayIsNotEnough() {
        let s = apply([(.answered(correct: false), day1), (.answered(correct: true), day1), (.answered(correct: true), day1)])
        #expect(s.state == .struggling)
        #expect(s.correctStreak == 1)
    }

    @Test func twoCorrectOnDifferentDaysIsLearned() {
        let s = apply([(.answered(correct: false), day1), (.answered(correct: true), day1), (.answered(correct: true), day2)])
        #expect(s.state == .learned)
    }

    @Test func wrongAnswerResetsTheStreak() {
        let s = apply([
            (.markedStruggling, day1),
            (.answered(correct: true), day1),
            (.answered(correct: false), day2),
            (.answered(correct: true), day3),
        ])
        #expect(s.state == .struggling)
        #expect(s.correctStreak == 1)
    }

    @Test func buttonsSetStateDirectly() {
        #expect(apply([(.markedKnown, day1)]).state == .learned)
        let s = apply([(.markedStruggling, day1)], from: CardState(cardID: "x", state: .learned, correctStreak: 2))
        #expect(s.state == .struggling && s.correctStreak == 0)
    }

    @Test func favoriteAndShownCountsSurviveEvents() {
        let start = CardState(cardID: "x", timesShown: 4, favorite: true)
        let s = apply([(.answered(correct: false), day1), (.markedKnown, day2)], from: start)
        #expect(s.favorite && s.timesShown == 4)
    }

    @Test func storeUsesLocalDaysAcrossMidnight() throws {
        // 23:50 and 00:10 Istanbul time are the same UTC day but different local days.
        let istanbul = TimeZone(identifier: "Europe/Istanbul")!
        let late = AppClock.fixed(try Date("2026-10-13T20:50:00Z", strategy: .iso8601), timeZone: istanbul)
        let early = AppClock.fixed(try Date("2026-10-13T21:10:00Z", strategy: .iso8601), timeZone: istanbul)
        let db = try AppDatabase.inMemory()
        let state = try db.writer.write { db in
            try LearningStore.record(.markedStruggling, cardID: "x", source: .wordDetail, clock: late, db: db)
            try LearningStore.record(.answered(correct: true), cardID: "x", source: .quickReview, clock: late, db: db)
            return try LearningStore.record(.answered(correct: true), cardID: "x", source: .quickReview, clock: early, db: db)
        }
        #expect(state.state == .learned)
        let logs = try db.reader.read { db in try ReviewLog.order(Column("id")).fetchAll(db) }
        #expect(logs.map(\.answeredOn.string) == ["2026-10-13", "2026-10-14"])
    }

    @Test func storeLogsAnswersOnly() throws {
        let db = try AppDatabase.inMemory()
        let clock = AppClock.fixed(Date(timeIntervalSince1970: 1_800_000_000), timeZone: .gmt)
        try db.writer.write { db in
            try LearningStore.record(.hintUsed, cardID: "x", source: .puzzle, clock: clock, db: db)
            try LearningStore.record(.markedKnown, cardID: "x", source: .widget, clock: clock, db: db)
            try LearningStore.record(.answered(correct: false), cardID: "x", source: .widget, clock: clock, sessionID: "s1", db: db)
            try LearningStore.setFavorite(true, cardID: "x", db: db)
        }
        try db.reader.read { db throws in
            #expect(try ReviewLog.fetchCount(db) == 1)
            #expect(try ReviewLog.fetchOne(db)?.sessionID == "s1")
            let s = try LearningStore.state(of: "x", db: db)
            #expect(s.state == .struggling && s.favorite)
        }
    }
}
