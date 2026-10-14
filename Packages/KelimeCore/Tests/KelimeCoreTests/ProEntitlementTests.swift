import Foundation
import Testing
@testable import KelimeCore

struct ProEntitlementTests {
    @Test func activeProductsGrantPro() {
        #expect(ProEntitlement.isPro(activeProductIDs: ["pro.lifetime"]))
        #expect(ProEntitlement.isPro(activeProductIDs: ["other", "pro.yearly"]))
        #expect(!ProEntitlement.isPro(activeProductIDs: []))
        #expect(!ProEntitlement.isPro(activeProductIDs: ["pro.monthly"]))
    }

    @Test func cacheReportsChanges() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            #expect(try ProEntitlement.cache(false, db: db) == false)
            #expect(try ProEntitlement.cache(true, db: db) == true)
            #expect(try ProEntitlement.cache(true, db: db) == false)
            #expect(try Settings.bool(.isPro, in: db))
            #expect(try ProEntitlement.cache(false, db: db) == true)
        }
    }

    @Test func proUnlocksGates() throws {
        let db = try AppDatabase.inMemory()
        let clock = AppClock.fixed(Date(timeIntervalSince1970: 1_800_000_000), timeZone: .gmt)
        try db.writer.write { db throws in
            try LearningStore.record(.answered(correct: true), cardID: "x", source: .quickReview, clock: clock, sessionID: "s", db: db)
            #expect(try QuickReviewLimit.remaining(db: db, clock: clock) == 0)
            try ProEntitlement.cache(true, db: db)
            #expect(try QuickReviewLimit.remaining(db: db, clock: clock) == nil)
            var prefs = try Preferences.load(db)
            prefs.rotationInterval = .thirtyMinutes
            prefs.enabledDecks = [.yds]
            #expect(prefs.effectiveRotation == .thirtyMinutes)
            #expect(prefs.entitledDecks == [.yds])
        }
    }
}
