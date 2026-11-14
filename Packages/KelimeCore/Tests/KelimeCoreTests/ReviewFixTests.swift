import Foundation
import GRDB
import Testing
@testable import KelimeCore

/// Fixes from the review of 1.2 §1–§3.
struct ReviewFixTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let hour: TimeInterval = 3600

    // MARK: The trial's end is cached; widgets and gates work out "bought or before the end"

    @Test func trialEndedWhileTheAppStayedClosedIsNotPro() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try ProEntitlement.cacheTrialEnd(t0 + 72 * hour, db: db)
            #expect(try ProEntitlement.isPro(db: db, now: t0 + 71 * hour))
            #expect(try !ProEntitlement.isPro(db: db, now: t0 + 72 * hour)) // exactly 72 h: over
            #expect(try !ProEntitlement.isPro(db: db, now: t0 + 100 * hour))
            // Gates and widgets read the same answer.
            #expect(try Preferences.load(db).isPro == ProEntitlement.isPro(db: db))
        }
    }

    @Test func purchaseOrDeveloperGrantIgnoresTheTrialEnd() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try ProEntitlement.cacheTrialEnd(t0, db: db)
            try ProEntitlement.cache(true, db: db)
            #expect(try ProEntitlement.isPro(db: db, now: t0 + 500 * hour))
            #expect(try ProEntitlement.cacheTrialEnd(nil, db: db))
            #expect(try ProEntitlement.cacheTrialEnd(nil, db: db) == false)
        }
    }

    @Test func savingPreferencesNeverTurnsTheTrialIntoAGrant() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try ProEntitlement.cacheTrialEnd(Date().addingTimeInterval(hour), db: db)
            var prefs = try Preferences.load(db)
            #expect(prefs.isPro)
            prefs.theme = .paper
            try prefs.save(db)
            #expect(try Settings.bool(.isPro, in: db) == false)
        }
    }

    @Test func streakFreezesFollowTheTrialEnd() throws {
        let db = try AppDatabase.inMemory()
        let during = AppClock.fixed(t0 + hour, timeZone: TimeZone(identifier: "UTC")!)
        let after = AppClock.fixed(t0 + 80 * hour, timeZone: TimeZone(identifier: "UTC")!)
        try db.writer.write { db in
            try ProEntitlement.cacheTrialEnd(t0 + 72 * hour, db: db)
            #expect(try ProEntitlement.isPro(db: db, now: during.now))
            #expect(try !ProEntitlement.isPro(db: db, now: after.now))
            #expect(Streak.freezes(isPro: try ProEntitlement.isPro(db: db, now: during.now)) == 2)
            #expect(Streak.freezes(isPro: try ProEntitlement.isPro(db: db, now: after.now)) == 1)
            // Reading the status through the clock agrees.
            _ = try Streak.status(db: db, clock: during)
            _ = try Streak.status(db: db, clock: after)
        }
    }

    // MARK: The last known purchase survives a launch without an answer

    @Test func purchaseIsRememberedAndSurvivesAProgressReset() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            #expect(try !ProEntitlement.isPurchasedCached(db: db))
            try ProEntitlement.cachePurchased(true, db: db)
            try ProEntitlement.cacheTrialEnd(t0, db: db)
            try ProgressReset.reset(db: db)
            #expect(try ProEntitlement.isPurchasedCached(db: db))
            #expect(try Settings.int(.trialEnd, in: db) == Int(t0.timeIntervalSince1970))
            try ProEntitlement.cachePurchased(false, db: db)
            #expect(try !ProEntitlement.isPurchasedCached(db: db))
        }
    }

    // MARK: The trial store is not written on every refresh

    @Test func refreshWritesOnlyWhenSomethingChanges() {
        let store = MemoryTrialStore()
        let m = ReverseTrialManager(store: store)
        m.refresh(now: t0)
        #expect(store.saves == 1) // started
        for minute in 1...30 { m.refresh(now: t0 + Double(minute) * 60) }
        #expect(store.saves == 1)
        // More than an hour later lastSeen is stored again.
        m.refresh(now: t0 + hour + 1)
        #expect(store.saves == 2)
        #expect(store.trial?.lastSeen == t0 + hour + 1)
        // The end is a change.
        m.refresh(now: t0 + 73 * hour)
        #expect(store.saves == 3)
        #expect(store.trial?.endedReported == true)
        m.refresh(now: t0 + 74 * hour + 1)
        #expect(store.saves == 4) // lastSeen moved by more than an hour since the last write
        m.refresh(now: t0 + 74 * hour + 2)
        #expect(store.saves == 4)
    }

    @Test func memoryKeepsTheClockFromGoingBackBetweenWrites() {
        let store = MemoryTrialStore()
        let m = ReverseTrialManager(store: store)
        m.refresh(now: t0)
        m.refresh(now: t0 + 71 * hour + 1800)
        // The clock is set back: the trial still counts from the latest time seen.
        let s = m.refresh(now: t0 + hour)
        #expect(s.trial?.lastSeen == t0 + 71 * hour + 1800)
        #expect(s.daysLeft == 1)
    }

    @Test func usesAndTheSummaryFlagStillReachTheStore() {
        let store = MemoryTrialStore()
        let m = ReverseTrialManager(store: store)
        m.refresh(now: t0)
        m.note(.archive, key: "2026-11-01", now: t0 + hour)
        m.note(.archive, key: "2026-11-01", now: t0 + hour)
        #expect(store.trial?.uses(.archive) == 1)
        m.refresh(now: t0 + 80 * hour)
        m.markSummaryShown()
        #expect(store.trial?.summaryShown == true)
        #expect(store.trial?.uses(.archive) == 1)
        // A fresh process reads it back.
        #expect(!ReverseTrialManager(store: store).refresh(now: t0 + 90 * hour).summaryDue)
    }

    // MARK: Read-only lists are not exported

    @Test func readOnlyListsCannotBeExportedAndFreeLearnersCannotExportAtAll() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            let first = try UserLists.create(title: "Bir", isPro: true, now: Date(timeIntervalSince1970: 1), db: db)
            let second = try UserLists.create(title: "İki", isPro: true, now: Date(timeIntervalSince1970: 2), db: db)
            #expect(try UserLists.canExport(first.id, isPro: true, db: db))
            #expect(try UserLists.canExport(second.id, isPro: true, db: db))
            // Free: no export, read-only or not.
            #expect(try !UserLists.canExport(first.id, isPro: false, db: db))
            #expect(try !UserLists.canExport(second.id, isPro: false, db: db))
        }
    }

    // MARK: Cleanup

    @Test func weekStartHasOneImplementation() {
        let sunday = LocalDate(year: 2026, month: 11, day: 22)
        #expect(StatsQueries.weekStart(for: sunday).string == "2026-11-16")
    }
}

/// Fixes from the review of 506f0c5..7dd11c4.
struct ReviewFix2Tests {
    func card(_ id: String = "c", en: String) -> Card {
        Card(id: id, word: "idea", pos: .noun, level: .b1, tr: ["anlam"], exampleEN: en, exampleTR: "Bir cümle.")
    }

    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let hour: TimeInterval = 3600

    @Test func aTrialThatEndedWhileTheAppWasClosedIsAChangeOnTheNextColdLaunch() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { try ProEntitlement.cacheTrialEnd(t0 + 72 * hour, db: $0) }
        func launch(at offset: TimeInterval) throws -> Bool {
            try db.writer.write { db in
                try ProEntitlement.noteEffective(try ProEntitlement.isPro(db: db, now: t0 + offset), db: db)
            }
        }
        #expect(try !launch(at: 10 * hour)) // first sight: only recorded
        #expect(try !launch(at: 20 * hour)) // unchanged
        // The app is closed; the trial ends without any write. A new process starts with no memory.
        #expect(try launch(at: 80 * hour))
        #expect(try !launch(at: 81 * hour))
    }

    @Test func aOneOneBuyerIsKeptOffline() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            #expect(try !ProEntitlement.isPurchasedCached(db: db))
            try Settings.set(.isPro, true, in: db) // 1.1 cached the purchase here
            #expect(try ProEntitlement.isPurchasedCached(db: db))
            try ProEntitlement.cachePurchased(false, db: db) // once 1.2 knows better, its row wins
            #expect(try !ProEntitlement.isPurchasedCached(db: db))
        }
    }

    @Test func capitalisedFirstWordsStayAsWritten() {
        func tokens(_ en: String) -> [String]? {
            SentenceTokens.tokens(card(en: en))
        }
        #expect(tokens("TV is on all day.")?.first == "TV")
        #expect(tokens("DNA tests are very common now.")?.first == "DNA")
        #expect(tokens("Can I ask you something?")?.first == "can")
    }

    @Test func noResultAndNoStreakForAnEmptyRound() throws {
        let db = try AppDatabase.inMemory()
        let clock = AppClock.fixed(t0, timeZone: TimeZone(identifier: "UTC")!)
        try db.writer.write { db in
            try GamePool.recordResult(game: .gapFill, score: 0, total: 0, seconds: 3, clock: clock, db: db)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM game_result") == 0)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM streak_day") == 0)
            try GamePool.recordResult(game: .gapFill, score: 0, total: 1, seconds: 3, clock: clock, db: db)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM game_result") == 1)
        }
    }

    @Test func aRoundNeverShowsTheSameSentenceTwice() throws {
        let cards = (0..<6).map { i in card("c\(i)", en: i < 3 ? "The cat sat on the mat." : "The dog ran in the park \(i).") }
        var rng = SystemRandomNumberGenerator()
        let game = SentenceGame(cards: cards, using: &rng)
        #expect(Set(game.items.map(\.sentence)).count == game.items.count)
        #expect(game.items.count == 4)
    }
}
