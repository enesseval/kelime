import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct WatchPayloadTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    let start = try! Date("2026-10-13T07:20:00Z", strategy: .iso8601) // 10:20 in Istanbul

    func clock(_ offset: TimeInterval = 0) -> AppClock {
        .fixed(start.addingTimeInterval(offset), timeZone: istanbul)
    }

    func makeDatabase(_ prefs: Preferences = Preferences(rotationInterval: .thirtyMinutes, isPro: true)) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try prefs.save(db)
        }
        return db
    }

    func payload(_ db: AppDatabase) throws -> WatchPayload {
        var rng = SeededGenerator(seed: 4)
        return try db.writer.write { db in try WatchPayload.make(db: db, clock: clock(), using: &rng) }
    }

    @Test func matchesTheIPhoneWidgetQueue() throws {
        let db = try makeDatabase()
        let payload = try payload(db)
        let queue = try db.reader.read { db in try WidgetQueue.current(db: db, clock: clock()) }
        #expect(payload.slots.count == 49)
        #expect(payload.slot(at: clock().now)?.card.id == queue?.cardID)
        // Round trip through JSON, the way it crosses to the watch.
        #expect(try WatchPayload.decode(payload.encoded()) == payload)
    }

    @Test func keepsShowingWordsAfterTheLastSlot() throws {
        let payload = try payload(try makeDatabase())
        let later = payload.end.addingTimeInterval(45 * 60)
        let slot = try #require(payload.slot(at: later))
        #expect(payload.slots.contains(slot))
        #expect(!payload.snapshots(from: later, calendar: clock().calendar).isEmpty)
    }

    @Test func reviewCountResetsAtMidnight() throws {
        var payload = try payload(try makeDatabase())
        payload.reviewedToday = 4
        #expect(payload.reviewed(on: payload.reviewedDay) == 4)
        #expect(payload.reviewed(on: payload.reviewedDay.adding(days: 1)) == 0)
    }

    @Test func watchActionsApplyLocallyAndOnThePhone() throws {
        let db = try makeDatabase()
        var payload = try payload(db)
        let slot = try #require(payload.slot(at: clock().now))
        let wrong = try #require(slot.quizOptions.first { $0 != slot.card.word })
        let answer = WatchAction.answer(cardID: slot.card.id, option: wrong, slotStart: slot.start)
        payload.apply(answer)
        #expect(payload.slot(at: clock().now)?.state == .struggling)
        #expect(payload.reviewedToday == 1)

        // It arrives on the phone after the slot is over: it still counts, once.
        let decoded = try WatchAction.decode(answer.encoded())
        try db.writer.write { db in
            try decoded.perform(db: db, clock: clock(2 * 3600))
            try decoded.perform(db: db, clock: clock(2 * 3600))
        }
        try db.reader.read { db throws in
            #expect(try LearningStore.state(of: slot.card.id, db: db).state == .struggling)
            #expect(try ReviewLog.fetchCount(db) == 1)
            #expect(try WidgetQueueEntry.fetchOne(db, key: slot.start)?.quizAnswer == wrong)
        }
    }
}
