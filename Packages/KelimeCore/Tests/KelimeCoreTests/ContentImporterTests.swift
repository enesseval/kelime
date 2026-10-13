import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct ContentImporterTests {
    let reluctant = TestSupport.card("reluctant", level: .b2, tr: ["isteksiz", "gönülsüz"])
    let reliable = TestSupport.card("reliable", level: .b1, tr: ["güvenilir"])
    let borrow = TestSupport.card("borrow", level: .a2, pos: .verb, tr: ["ödünç almak"])

    @Test func importsCardsAndDecks() async throws {
        let db = try AppDatabase.inMemory()
        let data = try TestSupport.cardsJSON(version: 1, [(reluctant, [.general, .yds]), (reliable, [.general])])

        let result = try await ContentImporter.importIfNeeded(data, into: db)

        #expect(result == .imported(version: 1, cardCount: 2))
        try await db.reader.read { db throws in
            #expect(try Card.fetchCount(db) == 2)
            #expect(try Card.fetchOne(db, key: "b2-reluctant") == reluctant)
            #expect(try CardDeck.filter(Column("deck") == DeckTag.yds).fetchCount(db) == 1)
            #expect(try Settings.int(.contentVersion, in: db) == 1)
        }
    }

    @Test func skipsWhenVersionUnchanged() async throws {
        let db = try AppDatabase.inMemory()
        let data = try TestSupport.cardsJSON(version: 3, [(reluctant, [.general])])
        _ = try await ContentImporter.importIfNeeded(data, into: db)
        #expect(try await ContentImporter.importIfNeeded(data, into: db) == .upToDate(version: 3))
    }

    @Test func versionChangeUpsertsAndKeepsProgress() async throws {
        let db = try AppDatabase.inMemory()
        _ = try await ContentImporter.importIfNeeded(
            try TestSupport.cardsJSON(version: 1, [(reluctant, [.general, .yds]), (reliable, [.general])]),
            into: db
        )
        try await db.writer.write { db in
            try CardState(cardID: "b2-reluctant", state: .struggling, correctStreak: 1, favorite: true).insert(db)
            try CardState(cardID: "b1-reliable", state: .learned).insert(db)
        }

        var edited = reluctant
        edited.exampleEN = "He was reluctant to talk."
        let result = try await ContentImporter.importIfNeeded(
            try TestSupport.cardsJSON(version: 2, [(edited, [.general]), (borrow, [.general])]),
            into: db
        )

        #expect(result == .imported(version: 2, cardCount: 2))
        try await db.reader.read { db throws in
            #expect(try Card.fetchOne(db, key: "b2-reluctant")?.exampleEN == "He was reluctant to talk.")
            #expect(try Card.fetchOne(db, key: "a2-borrow") != nil)
            #expect(try Card.fetchOne(db, key: "b1-reliable") == nil)
            #expect(try CardDeck.filter(Column("card_id") == "b2-reluctant").fetchCount(db) == 1)
            // Progress is untouched, including for the card that left the content.
            let state = try #require(try CardState.fetchOne(db, key: "b2-reluctant"))
            #expect(state.state == .struggling && state.correctStreak == 1 && state.favorite)
            #expect(try CardState.fetchOne(db, key: "b1-reliable")?.state == .learned)
        }
    }

    @Test func reportsProgressUpToOne() async throws {
        let db = try AppDatabase.inMemory()
        let cards = (0..<120).map { (TestSupport.card("word\($0)"), [DeckTag.general]) }
        let recorder = ProgressRecorder()
        _ = try await ContentImporter.importIfNeeded(try TestSupport.cardsJSON(version: 1, cards), into: db) { recorder.add($0) }
        let values = recorder.values
        #expect(values.last == 1)
        #expect(values == values.sorted())
        #expect(values.count > 2)
    }

    @Test func rejectsMalformedJSON() async throws {
        let db = try AppDatabase.inMemory()
        await #expect(throws: DecodingError.self) {
            _ = try await ContentImporter.importIfNeeded(Data("{\"cards\": []}".utf8), into: db)
        }
    }

    @Test func importsBundledContent() async throws {
        let data = try Data(contentsOf: TestSupport.bundledCardsURL)
        let file = try ContentImporter.decode(data)
        #expect(file.cards.count >= 150)
        #expect(Set(file.cards.map(\.card.id)).count == file.cards.count)

        let db = try AppDatabase.inMemory()
        _ = try await ContentImporter.importIfNeeded(data, into: db)
        #expect(try await db.reader.read { db in try Card.fetchCount(db) } == file.cards.count)
    }
}

final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Double] = []
    func add(_ value: Double) { lock.withLock { stored.append(value) } }
    var values: [Double] { lock.withLock { stored } }
}
