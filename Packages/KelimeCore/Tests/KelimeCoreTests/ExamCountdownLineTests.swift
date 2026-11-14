import Foundation
import GRDB
import Testing
@testable import KelimeCore

/// Sınav geri sayımı (docs/V1_2_PLAN.md §5); the same cases as Android's ExamCountdownLineTest.
struct ExamCountdownLineTests {
    private func plan(_ exam: DeckID = .yds, days: Int = 23, remaining: Int = 300, target: Int = 12, done: Int = 0) -> ExamPlanStatus {
        ExamPlanStatus(exam: exam, daysLeft: days, remaining: remaining, dailyTarget: target, doneToday: done, listOnWidget: true)
    }

    @Test func theLineReadsLikeThePlan() {
        #expect(ExamCountdownLine.text(isPro: true, plan: plan()) == "YDS'ye 23 gün · bugün 12 kelime")
        #expect(ExamCountdownLine.text(isPro: true, plan: plan(.yokdil, days: 5, target: 20)) == "YÖKDİL'e 5 gün · bugün 20 kelime")
        #expect(ExamCountdownLine.text(isPro: true, plan: plan(.ielts, days: 1)) == "IELTS'e 1 gün · bugün 12 kelime")
    }

    @Test func doneForTodayAndEverythingLearned() {
        #expect(ExamCountdownLine.text(isPro: true, plan: plan(done: 12)) == "YDS'ye 23 gün · bugünkü hedef tamam")
        #expect(ExamCountdownLine.text(isPro: true, plan: plan(remaining: 0, target: 0)) == "YDS'ye 23 gün · hepsini öğrendin")
    }

    @Test func examDayAndAfter() {
        #expect(ExamCountdownLine.text(isPro: true, plan: plan(days: 0)) == "YDS bugün · bugün 12 kelime")
        #expect(ExamCountdownLine.text(isPro: true, plan: nil) == nil)
        #expect(!ExamCountdownLine.available(isPro: true, plan: nil))
    }

    @Test func onlyForProAndTrial() {
        #expect(ExamCountdownLine.text(isPro: false, plan: plan()) == nil)
        #expect(ExamCountdownLine.available(isPro: true, plan: plan()))
        #expect(!ExamCountdownLine.available(isPro: false, plan: plan()))
    }

    @Test func runsOnlyWhenSwitchedOnProAndBeforeOrOnTheExamDay() {
        #expect(ExamCountdownLine.shouldRun(enabled: true, isPro: true, plan: plan()))
        #expect(ExamCountdownLine.shouldRun(enabled: true, isPro: true, plan: plan(days: 0)))
        #expect(!ExamCountdownLine.shouldRun(enabled: false, isPro: true, plan: plan()))
        #expect(!ExamCountdownLine.shouldRun(enabled: true, isPro: false, plan: plan()))
        #expect(!ExamCountdownLine.shouldRun(enabled: true, isPro: true, plan: nil))
    }

    @Test func theStateCarriesTheSameLine() {
        #expect(ExamCountdownState(plan()).line == "YDS'ye 23 gün · bugün 12 kelime")
        #expect(ExamCountdownState(plan(done: 12)).line == "YDS'ye 23 gün · bugünkü hedef tamam")
    }

    // MARK: Against the database

    private func setUp(exam: Date? = nil, on: Bool = true, trialEnd: Date? = nil, pro: Bool = false) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try Preferences(level: .b1, enabledDecks: [.b1]).save(db)
            try ExamCountdown.set(.yds, date: LocalDate(year: 2026, month: 12, day: 7), db: db)
            try Settings.set(.examCountdownOn, on, in: db)
            if pro { try ProEntitlement.cache(true, db: db) }
            try ProEntitlement.cacheTrialEnd(trialEnd, db: db)
        }
        return db
    }

    private func clock(_ day: String) -> AppClock {
        AppClock.fixed(try! Date("\(day)T10:00:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "UTC")!)
    }

    private func current(_ db: AppDatabase, _ day: String, now: Date) throws -> ExamPlanStatus? {
        try db.reader.read { try ExamCountdownLine.current(db: $0, clock: clock(day), now: now) }
    }

    @Test func offByDefault() throws {
        let db = try setUp(on: false, pro: true)
        #expect(try current(db, "2026-11-14", now: .now) == nil)
        #expect(try db.reader.read { try Settings.bool(.examCountdownOn, in: $0) } == false)
    }

    @Test func noDateMeansNoCountdown() throws {
        let db = try setUp(pro: true)
        try db.writer.write { try ExamCountdown.clear(db: $0) }
        #expect(try current(db, "2026-11-14", now: .now) == nil)
    }

    @Test func runsBeforeAndOnTheExamDayThenCloses() throws {
        let db = try setUp(pro: true)
        #expect(try #require(try current(db, "2026-11-14", now: .now)).daysLeft == 23)
        #expect(try #require(try current(db, "2026-12-07", now: .now)).daysLeft == 0)
        #expect(try current(db, "2026-12-08", now: .now) == nil)
    }

    @Test func endsAfterTheTrialExpiresWithoutAPurchase() throws {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let db = try setUp(trialEnd: t0 + 72 * 3600)
        #expect(try current(db, "2026-11-14", now: t0 + 71 * 3600) != nil)
        #expect(try current(db, "2026-11-14", now: t0 + 72 * 3600) == nil)
        #expect(try current(db, "2026-11-14", now: t0 + 100 * 3600) == nil)
        // A purchase keeps it.
        try db.writer.write { try ProEntitlement.cache(true, db: $0) }
        #expect(try current(db, "2026-11-14", now: t0 + 100 * 3600) != nil)
    }

    @Test func notProNoCountdown() throws {
        let db = try setUp()
        #expect(try current(db, "2026-11-14", now: .now) == nil)
    }

    @Test func studyingKeepsTheCountCurrent() throws {
        let db = try setUp(pro: true)
        let c = clock("2026-11-14")
        let before = try #require(try current(db, "2026-11-14", now: .now))
        try db.writer.write { try LearningStore.record(.answered(correct: true), cardID: "exam-hamper", source: .quickReview, clock: c, db: $0) }
        let after = try #require(try current(db, "2026-11-14", now: .now))
        #expect(after.doneToday == before.doneToday + 1)
    }

    @Test func theActivityRestartsBeforeItsLifetimeRunsOut() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!ExamCountdownLifetime.needsRestart(startedAt: t, now: t + 6 * 3600))
        #expect(ExamCountdownLifetime.needsRestart(startedAt: t, now: t + 7 * 3600))
    }

    @Test func onlyLiveActivitiesAreCurrent() {
        #expect(ExamCountdownLifetime.isCurrent(.active))
        #expect(ExamCountdownLifetime.isCurrent(.stale))
        #expect(!ExamCountdownLifetime.isCurrent(.ended))
        #expect(!ExamCountdownLifetime.isCurrent(.dismissed))
    }

    @Test func onlyALiveDismissalOfTheCurrentActivityIsASwipe() {
        func swipe(_ p: ExamCountdownLifetime.Phase, id: String = "a", current: String? = "a", sawEnded: Bool = false) -> Bool {
            ExamCountdownLifetime.isSwipe(phase: p, activityID: id, currentID: current, sawEnded: sawEnded)
        }
        #expect(swipe(.dismissed))
        #expect(!swipe(.ended)) // ended by the app or by the system
        #expect(!swipe(.active))
        #expect(!swipe(.stale))
        #expect(!swipe(.dismissed, id: "old")) // not the current activity
        #expect(!swipe(.dismissed, current: nil)) // the app ended it itself
        #expect(!swipe(.dismissed, sawEnded: true)) // the end being cleared away
    }

    @Test func clearingTheExamSwitchesTheCountdownOff() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try ExamCountdown.set(.yds, date: LocalDate(year: 2026, month: 12, day: 1), db: db)
            try Settings.set(.examCountdownOn, true, in: db)
            try ExamCountdown.clear(db: db)
            #expect(try !Settings.bool(.examCountdownOn, in: db))
        }
    }

    @Test func aPassedExamDaySwitchesItOffAndANewDateKeepsItOff() throws {
        let db = try setUp(pro: true)
        func off(_ day: String) throws -> Bool {
            try db.writer.write { try ExamCountdownLine.switchOffIfExamPassed(db: $0, clock: clock(day)) }
        }
        func on() throws -> Bool { try db.reader.read { try Settings.bool(.examCountdownOn, in: $0) } }
        #expect(try !off("2026-12-07")) // exam day itself
        #expect(try on())
        #expect(try off("2026-12-08"))
        #expect(try !on())
        try db.writer.write { try ExamCountdown.set(.yds, date: LocalDate(year: 2027, month: 3, day: 1), db: $0) }
        #expect(try !off("2026-12-09"))
        #expect(try !on())
        #expect(try current(db, "2026-12-09", now: .now) == nil)
    }

    @Test func aLapsedProLeavesTheSwitchOn() throws {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let db = try setUp(trialEnd: t0 - 3600)
        #expect(try current(db, "2026-11-14", now: t0) == nil)
        let switched = try db.writer.write { try ExamCountdownLine.switchOffIfExamPassed(db: $0, clock: clock("2026-11-14")) }
        #expect(!switched)
        #expect(try db.reader.read { try Settings.bool(.examCountdownOn, in: $0) })
    }
}
