import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct WidgetTimelineTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    let start = try! Date("2026-10-13T07:20:00Z", strategy: .iso8601) // 10:20 in Istanbul

    func clock(_ offset: TimeInterval = 0) -> AppClock {
        .fixed(start.addingTimeInterval(offset), timeZone: istanbul)
    }

    func makeDatabase(_ prefs: Preferences = Preferences()) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try prefs.save(db)
        }
        return db
    }

    func build(_ db: AppDatabase, mode: WidgetMode? = nil, at clock: AppClock? = nil) throws -> [WidgetSnapshot] {
        var rng = SeededGenerator(seed: 5)
        let c = clock ?? self.clock()
        return try db.writer.write { db in try WidgetTimelineBuilder.build(db: db, clock: c, mode: mode, using: &rng) }
    }

    @Test func emptyDatabaseGivesTheEmptyState() throws {
        let snapshots = try build(try AppDatabase.inMemory())
        #expect(snapshots.count == 1)
        #expect(snapshots[0].isEmpty)
    }

    @Test func cardModeHasOneEntryPerSlot() throws {
        let snapshots = try build(try makeDatabase())
        #expect(snapshots.count == 25)
        #expect(snapshots.allSatisfy { $0.mode == .card && $0.phase == .answer && $0.card != nil })
        #expect(snapshots.map(\.date) == snapshots.map(\.date).sorted())
    }

    @Test func modeDefaultsToTheAppSetting() throws {
        let db = try makeDatabase(Preferences(defaultWidgetMode: .sentence))
        #expect(try build(db).allSatisfy { $0.mode == .sentence })
        #expect(try build(db, mode: .card).allSatisfy { $0.mode == .card })
    }

    /// Kendini sına cycles inside a slot: question 20 minutes, answer 10, and again. The old
    /// single question (first 30 minutes of three hours) left the answer on screen most of the day.
    @Test func selfTestCyclesQuestionAndAnswerInsideASlot() throws {
        let threeHours = try build(try makeDatabase(), mode: .selfTest)
        let firstSlot = threeHours.filter { $0.slotStart == threeHours[0].slotStart }
        #expect(firstSlot.count == 12)
        #expect(firstSlot.map { $0.date.timeIntervalSince($0.slotStart) / 60 } == [0, 20, 30, 50, 60, 80, 90, 110, 120, 140, 150, 170])
        #expect(firstSlot.enumerated().allSatisfy { $0.element.phase == ($0.offset % 2 == 0 ? .question : .answer) })
        #expect(Set(firstSlot.map(\.card)).count == 1)
        // 95 minutes into the slot the learner sees the question, not the answer.
        let at = threeHours[0].slotStart.addingTimeInterval(95 * 60)
        #expect(threeHours.last { $0.date <= at }?.phase == .question)
        #expect(threeHours.map(\.date) == threeHours.map(\.date).sorted())
        // Slots more than a day away keep one question and one answer.
        let lastSlot = threeHours.filter { $0.slotStart == threeHours.last?.slotStart }
        #expect(lastSlot.map(\.phase) == [.question, .answer])

        let halfHourly = try build(try makeDatabase(Preferences(rotationInterval: .thirtyMinutes, isPro: true)), mode: .selfTest)
        #expect(halfHourly[0].phase == .question && halfHourly[1].phase == .answer)
        #expect(halfHourly[1].date.timeIntervalSince(halfHourly[0].date) == 20 * 60)
        #expect(halfHourly[2].slotStart != halfHourly[0].slotStart)
    }

    @Test func snapshotsCarryStateQuizAndStruggling() throws {
        let db = try makeDatabase()
        let first = try build(db)[0]
        let cardID = try #require(first.card?.id)
        try db.writer.write { db in
            try WidgetActions.markStruggling(cardID: cardID, db: db, clock: clock())
        }
        let again = try build(db)[0]
        #expect(again.card?.id == cardID)
        #expect(again.state == .struggling)
        #expect(again.struggling.map(\.id) == [cardID])
        #expect(again.quizOptions.count == 2)
        #expect(again.quizCorrect == nil)
    }

    @Test func quizAnswerIsRecordedOncePerSlot() throws {
        let db = try makeDatabase()
        let first = try build(db)[0]
        let card = try #require(first.card)
        let wrong = try #require(first.quizOptions.first { $0 != card.word })

        let result = try db.writer.write { db in
            try WidgetActions.answerQuiz(cardID: card.id, option: wrong, db: db, clock: clock())
        }
        #expect(result == false)
        let second = try db.writer.write { db in
            try WidgetActions.answerQuiz(cardID: card.id, option: card.word, db: db, clock: clock())
        }
        #expect(second == nil)

        let after = try build(db)[0]
        #expect(after.quizAnswer == wrong)
        #expect(after.quizCorrect == false)
        #expect(after.state == .struggling)
        #expect(after.reviewedToday == 1)
    }

    @Test func quizForAnotherCardIsIgnored() throws {
        let db = try makeDatabase()
        _ = try build(db)
        let result = try db.writer.write { db in
            try WidgetActions.answerQuiz(cardID: "not-current", option: "x", db: db, clock: clock())
        }
        #expect(result == nil)
    }

    @Test func reviewCountResetsOnTheNextLocalDay() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            for _ in 0..<3 {
                try LearningStore.record(.answered(correct: true), cardID: "b1-curious", source: .quickReview, clock: clock(), db: db)
            }
        }
        let snapshots = try build(db)
        let todays = snapshots.filter { LocalDate($0.date, calendar: clock().calendar).string == "2026-10-13" }
        let tomorrows = snapshots.filter { LocalDate($0.date, calendar: clock().calendar).string == "2026-10-14" }
        #expect(!todays.isEmpty && !tomorrows.isEmpty)
        #expect(todays.allSatisfy { $0.reviewedToday == 3 })
        #expect(tomorrows.allSatisfy { $0.reviewedToday == 0 })

        let ring = try db.reader.read { db in try WidgetTimelineBuilder.ringSnapshots(db: db, clock: clock()) }
        #expect(ring.map(\.reviewedToday) == [3, 0])
        #expect(ring[1].date == LocalDate(year: 2026, month: 10, day: 14).startDate(in: clock().calendar))
    }

    @Test func markKnownLearnsTheCard() throws {
        let db = try makeDatabase()
        let card = try #require(try build(db)[0].card)
        try db.writer.write { db in try WidgetActions.markKnown(cardID: card.id, db: db, clock: clock()) }
        #expect(try build(db)[0].state == .learned)
    }

    @Test func selfTestPattern() {
        let p = SampleContent.reluctant.selfTestPattern
        #expect(p.first == "r")
        #expect(p.blanks == "________")
    }
}
