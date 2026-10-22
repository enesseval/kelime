import Foundation
import Testing
@testable import KelimeCore

struct OnboardingTests {
    @Test func savesChoicesAndFinishesOnboarding() throws {
        let db = try AppDatabase.inMemory()
        let choices = OnboardingChoices(level: .b2, reminderMinutes: 20 * 60 + 30)
        try db.writer.write { db in try choices.save(db: db) }
        try db.reader.read { db throws in
            let prefs = try Preferences.load(db)
            #expect(prefs.level == .b2)
            #expect(prefs.enabledDecks == [.b2])
            #expect(prefs.effectiveRotation == .threeHours)
            #expect(try ExamCountdown.load(db: db) == nil)
            #expect(try Settings.int(.reminderTime, in: db) == 1230)
            #expect(try Settings.bool(.onboardingDone, in: db))
        }
    }

    @Test func everyDeckIsFree() {
        let choices = OnboardingChoices(level: .c1)
        #expect(choices.decks == [.c1])
        #expect(DeckID.entitled(enabled: choices.decks) == [.c1])
        #expect(DeckID.entitled(enabled: []) == DeckID.basicDecks)
    }

    @Test func withoutProTheWidgetChangesEveryThreeHours() {
        for interval in RotationInterval.allCases {
            #expect(interval.effective(isPro: false) == .threeHours)
            #expect(interval.effective(isPro: true) == interval)
        }
    }

    @Test func examCountdown() throws {
        let db = try AppDatabase.inMemory()
        let clock = AppClock.fixed(try Date("2026-10-22T09:00:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "Europe/Istanbul")!)
        try db.writer.write { db in
            // Installs from before the exam choice only stored a YDS date.
            try Settings.set(.examDate, LocalDate(year: 2026, month: 11, day: 1), in: db)
        }
        #expect(try db.reader.read { db in try ExamCountdown.daysLeft(db: db, clock: clock) }.map { "\($0.exam.rawValue) \($0.days)" } == "YDS 10")
        try db.writer.write { db in try ExamCountdown.set(.ielts, date: LocalDate(year: 2026, month: 10, day: 21), db: db) }
        // A past exam shows no countdown.
        #expect(try db.reader.read { db in try ExamCountdown.daysLeft(db: db, clock: clock) } == nil)
        #expect(try db.reader.read { db in try ExamCountdown.load(db: db)?.exam } == .ielts)
        try db.writer.write { db in try ExamCountdown.clear(db: db) }
        #expect(try db.reader.read { db in try ExamCountdown.load(db: db) } == nil)
    }

    @Test func themesFollowEntitlement() throws {
        #expect(WidgetThemeID.paper.effective(isPro: false) == .paper)
        #expect(WidgetThemeID.ember.effective(isPro: false) == .paper)
        #expect(WidgetThemeID.ember.effective(isPro: true) == .ember)
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            var prefs = try Preferences.load(db)
            prefs.theme = .mono
            try prefs.save(db)
        }
        let prefs = try db.reader.read { db in try Preferences.load(db) }
        #expect(prefs.theme == .mono && prefs.effectiveTheme == .paper)
    }

    @Test func levelSamplesHaveThreeWords() {
        for level in CEFRLevel.allCases {
            #expect(LevelSamples.words(for: level).count == 3)
        }
    }
}
