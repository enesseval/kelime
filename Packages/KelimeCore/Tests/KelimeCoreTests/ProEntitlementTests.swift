import Foundation
import Testing
@testable import KelimeCore

struct ProEntitlementTests {
    @Test func activeProductsGrantPro() {
        #expect(ProEntitlement.isPro(activeProductIDs: ["pro.lifetime"]))
        #expect(ProEntitlement.isPro(activeProductIDs: ["other", "pro.yearly"]))
        #expect(!ProEntitlement.isPro(activeProductIDs: []))
        #expect(ProEntitlement.isPro(activeProductIDs: ["pro.monthly"]))
        #expect(!ProEntitlement.isPro(activeProductIDs: ["pro.weekly"]))
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

    @Test func proUnlocksFasterRotation() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            var prefs = try Preferences.load(db)
            prefs.rotationInterval = .thirtyMinutes
            #expect(prefs.effectiveRotation == .threeHours)
            try ProEntitlement.cache(true, db: db)
            prefs = try Preferences.load(db)
            prefs.rotationInterval = .thirtyMinutes
            #expect(prefs.effectiveRotation == .thirtyMinutes)
        }
    }
}
