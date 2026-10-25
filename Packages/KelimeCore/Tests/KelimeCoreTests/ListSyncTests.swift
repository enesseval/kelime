import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct ListSyncTests {
    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try Preferences(level: .a1, enabledDecks: [.a1]).save(db)
        }
        return db
    }

    @Test func uploadsOwnListsUntilTheyMatchTheServer() throws {
        let db = try makeDatabase()
        let list = try db.writer.write { db in
            let list = try UserLists.create(title: "Gezi", isPro: false, db: db)
            try UserLists.add(cardID: "a1-coffee", to: list.id, db: db)
            try UserLists.addCustom(word: "boarding pass", meaning: "biniş kartı", pos: .noun, level: .a1, to: list.id, db: db)
            try UserLists.import(SharedList(title: "Arkadaştan", cards: [SampleContent.happy]), db: db)
            return list
        }
        let pending = try db.reader.read { db in try ListSync.pendingUploads(db: db) }
        #expect(pending.map(\.id) == [list.id])
        #expect(pending[0].cards.count == 2)
        try db.writer.write { db in try ListSync.uploaded(list.id, serverTime: .now.addingTimeInterval(5), db: db) }
        #expect(try db.reader.read { db in try ListSync.pendingUploads(db: db) }.isEmpty)
        try db.writer.write { db in try UserLists.setVisibility(.public, list: list.id, db: db) }
        // The local clock may be behind the server's stamp; a change still counts.
        try db.writer.write { db in try db.execute(sql: "UPDATE user_list SET updated_at = ? WHERE id = ?", arguments: [Date.now.addingTimeInterval(10), list.id]) }
        #expect(try db.reader.read { db in try ListSync.pendingUploads(db: db) }.first?.visibility == .public)
    }

    @Test func mergeAddsReplacesAndDeletes() throws {
        let db = try makeDatabase()
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let own = Card(id: "user-abc", word: "gate", pos: .noun, level: .a1, tr: ["kapı"], exampleEN: "", exampleTR: "")
        let remote = RemoteList(id: "11111111-1111-1111-1111-111111111111", title: "Uçuş", visibility: .link,
                                cards: [own, SampleContent.happy], updatedAt: t0)
        try db.writer.write { db in try ListSync.merge([remote], db: db) }
        let cards = try db.reader.read { db in try UserLists.cards(of: remote.id, db: db).map(\.id) }
        #expect(cards.contains("user-abc"))
        #expect(try db.reader.read { db in try ListSync.pendingUploads(db: db) }.isEmpty)

        var renamed = remote
        renamed.title = "Uçuş 2"
        renamed.cards = [own]
        renamed.updatedAt = t0.addingTimeInterval(60)
        try db.writer.write { db in try ListSync.merge([renamed], db: db) }
        let list = try db.reader.read { db in try UserLists.list(id: remote.id, db: db) }
        #expect(list?.title == "Uçuş 2")
        #expect(try db.reader.read { db in try UserLists.cards(of: remote.id, db: db).count } == 1)

        // Deleted on another device.
        try db.writer.write { db in try ListSync.merge([], db: db) }
        #expect(try db.reader.read { db in try UserLists.list(id: remote.id, db: db) } == nil)
        #expect(try db.reader.read { db in try Card.exists(db, key: "user-abc") } == false)
    }

    @Test func deletingASyncedListQueuesTheServerDelete() throws {
        let db = try makeDatabase()
        let list = try db.writer.write { db in try UserLists.create(title: "Gezi", isPro: false, db: db) }
        try db.writer.write { db in
            try ListSync.uploaded(list.id, serverTime: .now, db: db)
            try UserLists.delete(list.id, db: db)
        }
        #expect(try db.reader.read { db in try ListSync.pendingDeletions(db: db) } == [list.id])
        // A server copy still listed must not come back while the delete is pending.
        let stale = RemoteList(id: list.id, title: "Gezi", visibility: .private, cards: [], updatedAt: .now.addingTimeInterval(60))
        try db.writer.write { db in try ListSync.merge([stale], db: db) }
        #expect(try db.reader.read { db in try UserLists.list(id: list.id, db: db) } == nil)
    }
}
