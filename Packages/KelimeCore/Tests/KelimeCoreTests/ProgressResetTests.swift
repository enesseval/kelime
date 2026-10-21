import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct ProgressResetTests {
    @Test func startsOverButKeepsContentAndPurchase() throws {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try Settings.set(.contentVersion, file.contentVersion, in: db)
            try Preferences(level: .b1).save(db)
            try Settings.set(.isPro, true, in: db)
            try Settings.set(.onboardingDone, true, in: db)
            try Curriculum.start("a1-cafe", db: db)
            try CardState(cardID: "a1-cafe", state: .learned).insert(db)
        }
        #expect(try db.writer.write { db in try ProgressReset.resetIfNeeded(db: db) })
        try db.reader.read { db throws in
            #expect(try CardState.fetchCount(db) == 0)
            #expect(try Settings.bool(.onboardingDone, in: db) == false)
            #expect(try Settings.string(.unitsStarted, in: db) == nil)
            #expect(try Settings.int(.contentVersion, in: db) == file.contentVersion)
            #expect(try Settings.bool(.isPro, in: db))
            #expect(try Preferences.load(db).enabledDecks == [.a1])
            let candidates = try CardQueries.candidates(in: [.a1], db: db)
            let onlyA1 = try candidates.allSatisfy { try Card.fetchOne(db, key: $0.cardID)?.level == .a1 }
            #expect(onlyA1)
            #expect(try Card.fetchCount(db) == file.cards.count)
        }
        // Only once per epoch.
        #expect(try db.writer.write { db in try ProgressReset.resetIfNeeded(db: db) } == false)
    }

    @Test func onlyLevelsWithUnitsArePickable() throws {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        #expect(try db.reader.read { db in try Curriculum.levels(db: db) } == [.a1, .a2, .b1, .b2])
    }
}
