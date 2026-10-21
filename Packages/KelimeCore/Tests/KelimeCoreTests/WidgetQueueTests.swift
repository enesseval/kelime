import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct WidgetQueueTests {
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

    func refill(_ db: AppDatabase, at clock: AppClock, seed: UInt64 = 7) throws -> [WidgetQueueEntry] {
        var rng = SeededGenerator(seed: seed)
        return try db.writer.write { db in try WidgetQueue.refill(db: db, clock: clock, using: &rng) }
    }

    @Test func fillsTheNext24HoursFromFreeDecks() throws {
        let db = try makeDatabase()
        let entries = try refill(db, at: clock())
        #expect(entries.count == 9)
        try db.reader.read { db throws in
            for entry in entries {
                let card = try #require(try Card.fetchOne(db, key: entry.cardID))
                #expect([CEFRLevel.a2, .b1].contains(card.level))
                #expect(entry.quizOptions.count == 2)
                #expect(entry.quizOptions.contains(card.word))
                #expect(Set(entry.quizOptions).count == 2)
            }
        }
        #expect(Set(entries.map(\.cardID)).count == entries.count)
    }

    @Test func refillIsIdempotentAndKeepsQuizAnswers() throws {
        let db = try makeDatabase()
        let first = try refill(db, at: clock())
        try db.writer.write { db in
            try WidgetQueue.recordQuizAnswer(first[0].quizOptions[0], slotStart: first[0].slotStart, db: db)
        }
        let second = try refill(db, at: clock(600), seed: 99)
        #expect(second.map(\.cardID) == first.map(\.cardID))
        #expect(second[0].quizAnswer == first[0].quizOptions[0])
    }

    @Test func movingForwardDropsOldSlotsAndAddsNewOnes() throws {
        let db = try makeDatabase()
        let first = try refill(db, at: clock())
        let later = try refill(db, at: clock(4 * 3600))
        #expect(later.count == 9)
        #expect(later.first!.slotStart == first[1].slotStart)
        #expect(Array(later.prefix(8)).map(\.cardID) == Array(first.dropFirst()).map(\.cardID))
        let total = try db.reader.read { db in try WidgetQueueEntry.fetchCount(db) }
        #expect(total == 10) // one past slot kept as history
    }

    @Test func neverRepeatsWithinTwentySlotsAcrossRefills() throws {
        let db = try makeDatabase(Preferences(rotationInterval: .thirtyMinutes, isPro: true))
        var shown: [Date: String] = [:]
        for hour in stride(from: 0, to: 24 * 4, by: 5) {
            for e in try refill(db, at: clock(TimeInterval(hour) * 3600), seed: UInt64(hour)) {
                shown[e.slotStart] = e.cardID
            }
        }
        let ordered = shown.sorted { $0.key < $1.key }.map(\.value)
        #expect(ordered.count > 150)
        for i in ordered.indices {
            let window = ordered[max(0, i - 20)..<i]
            #expect(!window.contains(ordered[i]))
        }
    }

    @Test func rotationSettingChangesTheGrid() throws {
        let db = try makeDatabase(Preferences(rotationInterval: .thirtyMinutes, isPro: false))
        #expect(try refill(db, at: clock()).count == 9) // free users fall back to 3 hours
        try db.writer.write { db in try Settings.set(.isPro, true, in: db) }
        #expect(try refill(db, at: clock()).count == 49)
        try db.writer.write { db in try Settings.set(.rotationInterval, RotationInterval.daily.minutes, in: db) }
        let daily = try refill(db, at: clock())
        #expect(daily.count == 2)
        let future = try db.reader.read { db in
            try WidgetQueueEntry.filter(WidgetQueueEntry.Columns.slotStart >= daily[0].slotStart).fetchCount(db)
        }
        #expect(future == 2)
    }

    @Test func proDecksRequirePro() throws {
        let free = try makeDatabase(Preferences(enabledDecks: [.yds], isPro: false))
        let pro = try makeDatabase(Preferences(enabledDecks: [.yds], isPro: true))
        let freeEntries = try refill(free, at: clock())
        let proEntries = try refill(pro, at: clock())
        try free.reader.read { db throws in
            for e in freeEntries {
                #expect([CEFRLevel.a2, .b1].contains(try Card.fetchOne(db, key: e.cardID)!.level))
            }
        }
        try pro.reader.read { db throws in
            for e in proEntries {
                #expect(try CardDeck.filter(Column("card_id") == e.cardID && Column("deck") == DeckTag.yds).fetchCount(db) == 1)
            }
        }
    }

    @Test func startedSlotsAreCountedOnce() throws {
        let db = try makeDatabase()
        let entries = try refill(db, at: clock())
        _ = try refill(db, at: clock(60))
        _ = try refill(db, at: clock(3 * 3600))
        try db.reader.read { db throws in
            let first = try LearningStore.state(of: entries[0].cardID, db: db)
            #expect(first.timesShown == 1)
            #expect(first.lastShownAt == entries[0].slotStart)
            let second = try LearningStore.state(of: entries[1].cardID, db: db)
            #expect(second.timesShown == 1)
            let third = try LearningStore.state(of: entries[2].cardID, db: db)
            #expect(third.timesShown == 0)
        }
    }

    @Test func strugglingCardsShowUpMoreOften() throws {
        let db = try makeDatabase(Preferences(rotationInterval: .thirtyMinutes, isPro: true))
        let struggling = try db.writer.write { db -> Set<String> in
            let ids = try String.fetchAll(db, sql: "SELECT card_id FROM unit_card WHERE unit_id IN ('a2-core', 'b1-core') ORDER BY card_id LIMIT 10")
            for id in ids { try CardState(cardID: id, state: .struggling).insert(db) }
            return Set(ids)
        }
        var hits = 0, total = 0
        for day in 0..<10 {
            for e in try refill(db, at: clock(TimeInterval(day) * 24 * 3600), seed: UInt64(day)) {
                total += 1
                if struggling.contains(e.cardID) { hits += 1 }
            }
        }
        // 10 of 109 free cards (the A2 and B1 cores) carry weight 3: about 25% of slots instead of 9%.
        let share = Double(hits) / Double(total)
        #expect(share > 0.15)
    }

    @Test func emptyContentGivesNoEntries() throws {
        let db = try AppDatabase.inMemory()
        var rng = SeededGenerator(seed: 1)
        let entries = try db.writer.write { db in try WidgetQueue.refill(db: db, clock: clock(), using: &rng) }
        #expect(entries.isEmpty)
    }

    @Test func distractorsPreferSameLevelAndPartOfSpeech() throws {
        let db = try makeDatabase()
        var rng = SeededGenerator(seed: 11)
        try db.reader.read { db throws in
            let card = try #require(try Card.fetchOne(db, key: "b2-reluctant"))
            let words = try CardQueries.distractors(for: card, count: 3, db: db, using: &rng)
            #expect(words.count == 3)
            #expect(!words.contains("reluctant"))
            for word in words {
                let other = try #require(try Card.filter(Card.Columns.word == word).fetchOne(db))
                #expect(other.level == .b2 && other.pos == .adjective)
            }
            let options = try CardQueries.quizOptions(for: card, optionCount: 4, db: db, using: &rng)
            #expect(options.count == 4 && options.contains("reluctant"))
        }
    }

    @Test func distractorsNeverShareTheAnswersMeaning() throws {
        // convince and persuade are both "ikna etmek": one can't be a wrong option for the other.
        let db = try makeDatabase()
        try db.reader.read { db throws in
            let convince = try #require(try Card.fetchOne(db, key: "b2-convince"))
            let all = try Card.fetchAll(db)
            for seed in UInt64(0)..<200 {
                var rng = SeededGenerator(seed: seed)
                let options = try CardQueries.quizOptions(for: convince, optionCount: 4, db: db, using: &rng)
                #expect(!options.contains("persuade"))
                for word in options where word != convince.word {
                    let other = try #require(all.first { $0.word == word })
                    #expect(Card.normalizedMeanings(other.tr).isDisjoint(with: Card.normalizedMeanings(convince.tr)))
                }
            }
        }
    }

    @Test func clearFutureKeepsTheCurrentSlot() throws {
        let db = try makeDatabase()
        let entries = try refill(db, at: clock())
        try db.writer.write { db in try WidgetQueue.clearFuture(db: db, clock: clock()) }
        let current = try db.reader.read { db in try WidgetQueue.current(db: db, clock: clock()) }
        #expect(current?.cardID == entries[0].cardID)
        #expect(try db.reader.read { db in try WidgetQueueEntry.fetchCount(db) } == 1)
    }
}
