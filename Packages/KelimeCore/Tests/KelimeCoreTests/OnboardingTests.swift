import Foundation
import Testing
@testable import KelimeCore

struct OnboardingTests {
    @Test func savesChoicesAndFinishesOnboarding() throws {
        let db = try AppDatabase.inMemory()
        let choices = OnboardingChoices(goal: .yds, examDate: LocalDate(year: 2026, month: 11, day: 16), level: .b2, rotation: .daily, reminderMinutes: 20 * 60 + 30)
        try db.writer.write { db in try choices.save(db: db) }
        try db.reader.read { db throws in
            let prefs = try Preferences.load(db)
            #expect(prefs.level == .b2)
            #expect(prefs.enabledDecks == [.b2, .yds])
            #expect(prefs.rotationInterval == .daily)
            #expect(try Settings.string(.goal, in: db) == "yds")
            #expect(try Settings.date(.examDate, in: db)?.string == "2026-11-16")
            #expect(try Settings.int(.reminderTime, in: db) == 1230)
            #expect(try Settings.bool(.onboardingDone, in: db))
        }
    }

    @Test func noProChoicesWithoutPro() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try OnboardingChoices(goal: .general, examDate: LocalDate(year: 2026, month: 1, day: 1), level: .a2, rotation: .thirtyMinutes).save(db: db)
        }
        try db.reader.read { db throws in
            let prefs = try Preferences.load(db)
            #expect(prefs.rotationInterval == .threeHours)
            #expect(prefs.enabledDecks == [.a2, .b1])
            // The exam date only applies to the YDS goal.
            #expect(try Settings.date(.examDate, in: db) == nil)
            #expect(try Settings.int(.reminderTime, in: db) == nil)
        }
    }

    @Test func freeUsersAtHigherLevelsFallBackToFreeDecks() {
        let choices = OnboardingChoices(level: .c1)
        #expect(choices.decks == [.c1])
        #expect(DeckID.entitled(enabled: choices.decks, isPro: false) == [.a2, .b1])
        #expect(DeckID.entitled(enabled: choices.decks, isPro: true) == [.c1])
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
