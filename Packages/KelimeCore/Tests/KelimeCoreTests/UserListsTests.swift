import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct UserListsTests {
    let clock = AppClock.fixed(try! Date("2026-10-24T07:00:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "Europe/Istanbul")!)

    func makeDatabase(_ prefs: Preferences = Preferences(level: .a1, enabledDecks: [.a1])) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try prefs.save(db)
        }
        return db
    }

    @Test func freeUsersHaveOneListAndImportsDoNotCount() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try UserLists.create(title: "  İş  ", isPro: false, db: db)
            #expect(throws: UserListError.limitReached) { try UserLists.create(title: "İkinci", isPro: false, db: db) }
            #expect(throws: UserListError.emptyTitle) { try UserLists.create(title: " ", isPro: true, db: db) }
            try UserLists.create(title: "Pro ile", isPro: true, db: db)
            try UserLists.import(SharedList(title: "Arkadaştan", cards: [SampleContent.happy]), db: db)
        }
        let titles = try db.reader.read { db in try UserLists.summaries(db: db).map(\.list.title) }
        #expect(titles == ["İş", "Pro ile", "Arkadaştan"])
    }

    @Test func addsAppWordsAndOwnWords() throws {
        let db = try makeDatabase()
        let list = try db.writer.write { db in try UserLists.create(title: "Gezi", isPro: false, db: db) }
        try db.writer.write { db in
            try UserLists.add(cardID: "a1-coffee", to: list.id, db: db)
            #expect(throws: UserListError.duplicateWord) { try UserLists.add(cardID: "a1-coffee", to: list.id, db: db) }
            let own = try UserLists.addCustom(word: "boarding pass", meaning: "biniş kartı, uçuş kartı", pos: .noun, level: .a1, to: list.id, db: db)
            #expect(own.id.hasPrefix(UserLists.customPrefix))
            #expect(own.pos == .phrase) // two words
            #expect(own.tr == ["biniş kartı", "uçuş kartı"])
            #expect(throws: UserListError.emptyWord) { try UserLists.addCustom(word: "gate", meaning: " ", pos: .noun, level: .a1, to: list.id, db: db) }
        }
        let cards = try db.reader.read { db in try UserLists.cards(of: list.id, db: db) }
        #expect(cards.map(\.word) == ["coffee", "boarding pass"])
        // Removing the own word deletes it; deleting the list keeps the app's card.
        try db.writer.write { db in
            try UserLists.remove(cardID: cards[1].id, from: list.id, db: db)
            #expect(try Card.fetchOne(db, key: cards[1].id) == nil)
            try UserLists.delete(list.id, db: db)
            #expect(try Card.fetchOne(db, key: "a1-coffee") != nil)
            #expect(try UserLists.summaries(db: db).isEmpty)
        }
    }

    @Test func contentUpdatesKeepOwnWords() throws {
        let db = try makeDatabase()
        let own = try db.writer.write { db -> Card in
            let list = try UserLists.create(title: "Benim", isPro: false, db: db)
            return try UserLists.addCustom(word: "serendipity", meaning: "mutlu tesadüf", pos: .noun, level: .a1, to: list.id, db: db)
        }
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        #expect(try db.reader.read { db in try Card.fetchOne(db, key: own.id) }?.word == "serendipity")
    }

    @Test func listsFeedTheWidgetAndQuickReview() throws {
        let db = try makeDatabase()
        let list = try db.writer.write { db -> UserList in
            let list = try UserLists.create(title: "B2", isPro: false, db: db)
            try UserLists.add(cardID: "b2-reluctant", to: list.id, db: db)
            try UserLists.addCustom(word: "zeal", meaning: "şevk", pos: .noun, level: .a1, to: list.id, db: db)
            return list
        }
        let ids = try db.reader.read { db in try CardQueries.candidates(in: [.a1], db: db).map(\.cardID) }
        #expect(ids.contains("b2-reluctant"))
        #expect(ids.contains { $0.hasPrefix(UserLists.customPrefix) })
        // With the course off, only the list counts: no fallback to the basic decks.
        try db.writer.write { db in
            var prefs = try Preferences.load(db)
            prefs.enabledDecks = []
            try prefs.save(db)
        }
        let onlyList = try db.reader.read { db in try CardQueries.candidates(in: try Preferences.load(db).entitledDecks, db: db).map(\.cardID) }
        #expect(onlyList.count == 2)
        // A list that is off feeds nothing.
        try db.writer.write { db in try UserLists.setEnabled(false, list: list.id, db: db) }
        let off = try db.reader.read { db in try CardQueries.candidates(in: [.a1], db: db).map(\.cardID) }
        #expect(!off.contains("b2-reluctant"))
    }

    @Test func sharedListsRoundTrip() throws {
        let db = try makeDatabase()
        let shared = try db.writer.write { db -> SharedList in
            let list = try UserLists.create(title: "Paylaş", isPro: true, db: db)
            try UserLists.add(cardID: "a1-happy", to: list.id, db: db)
            try UserLists.addCustom(word: "zeal", meaning: "şevk", pos: .noun, exampleEN: "Full of zeal.", level: .a1, to: list.id, db: db)
            return try #require(try UserLists.export(list.id, db: db))
        }
        let decoded = try SharedList.decode(try shared.encoded())
        #expect(decoded == shared)
        let other = try makeDatabase()
        let imported = try other.writer.write { db in try UserLists.import(decoded, db: db) }
        let cards = try other.reader.read { db in try UserLists.cards(of: imported.id, db: db) }
        #expect(imported.imported && imported.title == "Paylaş")
        // The app's word links to its card; the own word becomes a new own word.
        #expect(cards.map(\.word) == ["happy", "zeal"])
        #expect(cards[0].id == "a1-happy")
        #expect(cards[1].id.hasPrefix(UserLists.customPrefix) && cards[1].exampleEN == "Full of zeal.")
    }

    @Test func listWordsAreInTümüAndSuggestionsFindAppWords() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            let list = try UserLists.create(title: "Kelimeler", isPro: false, db: db)
            try UserLists.add(cardID: "c1-mitigate", to: list.id, db: db)
        }
        try db.reader.read { db throws in
            #expect(try WordQueries.list(segment: .all, db: db).contains { $0.id == "c1-mitigate" })
            #expect(try UserLists.suggestions("relu", db: db).first?.id == "b2-reluctant")
            #expect(try UserLists.suggestions("mutlu", db: db).contains { $0.id == "a1-happy" })
        }
    }
}
