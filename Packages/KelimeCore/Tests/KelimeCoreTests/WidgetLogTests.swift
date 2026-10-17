import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct WidgetLogTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    let start = try! Date("2026-10-13T07:20:00Z", strategy: .iso8601)

    func clock(_ offset: TimeInterval = 0) -> AppClock {
        .fixed(start.addingTimeInterval(offset), timeZone: istanbul)
    }

    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try Preferences(rotationInterval: .thirtyMinutes, isPro: true).save(db)
        }
        return db
    }

    @Test func tapsCompareTheShownEntryWithTheSchedule() throws {
        let db = try makeDatabase()
        let rows = try db.writer.write { db -> [WidgetLogEntry] in
            var rng = SeededGenerator(seed: 3)
            let queue = try WidgetQueue.refill(db: db, clock: clock(), using: &rng)
            // On time: the current slot's word.
            try WidgetLog.recordTap(source: "lock", cardID: queue[0].cardID, slot: queue[0].slotStart, db: db, clock: clock())
            // 10:20 + 50 min = 11:10: the widget still shows the 10:00 word; the 11:00 one is 10 min late.
            try WidgetLog.recordTap(source: "lock", cardID: queue[0].cardID, slot: queue[0].slotStart, db: db, clock: clock(50 * 60))
            return try WidgetLog.recent(db: db)
        }
        let late = try #require(rows.first)
        let onTime = try #require(rows.last)
        #expect(onTime.onTime == true && onTime.lag == nil)
        #expect(late.onTime == false)
        let lag = try #require(late.lag)
        #expect(lag == 10 * 60)
    }

    @Test func probeTimelineKeepsOnlyTheCurrentSlot() throws {
        let db = try makeDatabase()
        let snapshots = try db.writer.write { db in
            var rng = SeededGenerator(seed: 5)
            return try WidgetTimelineBuilder.build(db: db, clock: clock(), mode: .selfTest, using: &rng)
        }
        let (entries, reloadAt) = WidgetLog.probeTimeline(snapshots, now: clock().now)
        let slots = Array(Set(snapshots.map(\.slotStart))).sorted()
        #expect(Set(entries.map(\.slotStart)) == [slots[0]])
        #expect(entries.count == 2) // Kendini sına: question, then the answer in the same slot
        #expect(reloadAt == slots[1])
        #expect(reloadAt.timeIntervalSince(slots[0]) == 30 * 60)
    }

    @Test func logIsPruned() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            for i in 0..<(WidgetLog.maxRows + 50) {
                try WidgetLog.recordAppReload(reason: "\(i)", db: db, clock: clock(TimeInterval(i)))
            }
            #expect(try WidgetLogEntry.fetchCount(db) == WidgetLog.maxRows)
        }
    }
}
