import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct ProAuditTests {
    @Test func everyPaywallPromiseIsDelivered() throws {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try Preferences().save(db)
        }
        let istanbul = TimeZone(identifier: "Europe/Istanbul")!
        let clock = AppClock.fixed(try Date("2026-10-13T07:20:00Z", strategy: .iso8601), timeZone: istanbul)
        let items = ProAudit.run(source: db.reader, clock: clock)
        #expect(items.count == 7)
        for item in items {
            #expect(item.passed, "\(item.promise): \(item.detail)")
        }
        // The audit works on a copy: the user's settings are untouched.
        let prefs = try db.reader.read { db in try Preferences.load(db) }
        #expect(prefs == Preferences())
        #expect(try db.reader.read { db in try ReviewLog.fetchCount(db) } == 0)
    }
}
