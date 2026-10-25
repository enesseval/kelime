import Foundation
import GRDB

/// One of the learner's own lists as the account keeps it.
public struct RemoteList: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var visibility: ListVisibility
    public var cards: [Card]
    public var updatedAt: Date

    public init(id: String, title: String, visibility: ListVisibility, cards: [Card], updatedAt: Date) {
        self.id = id
        self.title = title
        self.visibility = visibility
        self.cards = cards
        self.updatedAt = updatedAt
    }
}

/// Two-way sync of the learner's own lists with their account. The server is a mirror: lists
/// changed here are uploaded, lists changed elsewhere replace the local copy, and the later
/// change wins. Lists saved from Keşfet or a file stay on this device.
public enum ListSync {
    /// Own lists changed here since they last matched the server.
    public static func pendingUploads(db: Database) throws -> [RemoteList] {
        try UserList.filter(Column("imported") == false).fetchAll(db)
            .filter(\.needsUpload)
            .map { list in
                RemoteList(id: list.id, title: list.title, visibility: list.visibility,
                           cards: try UserLists.cards(of: list.id, db: db), updatedAt: list.updatedAt ?? list.createdAt)
            }
    }

    /// Ids of synced lists deleted here, still to delete on the server.
    public static func pendingDeletions(db: Database) throws -> [String] {
        try String.fetchAll(db, sql: "SELECT id FROM user_list_deleted")
    }

    public static func deletionSent(_ id: String, db: Database) throws {
        try db.execute(sql: "DELETE FROM user_list_deleted WHERE id = ?", arguments: [id])
    }

    /// The upload went through; the server stamped it `serverTime`.
    public static func uploaded(_ id: String, serverTime: Date, db: Database) throws {
        try db.execute(sql: "UPDATE user_list SET synced_at = ?, updated_at = ? WHERE id = ?", arguments: [serverTime, serverTime, id])
    }

    /// Applies the account's lists: new ones are added, ones changed elsewhere replace the local
    /// copy unless it changed here too, and synced ones missing from the server were deleted on
    /// another device. Returns whether anything changed.
    @discardableResult
    public static func merge(_ remote: [RemoteList], db: Database) throws -> Bool {
        var changed = false
        let deleted = Set(try pendingDeletions(db: db))
        let remoteIDs = Set(remote.map(\.id))
        for item in remote where !deleted.contains(item.id) {
            if var local = try UserList.fetchOne(db, key: item.id) {
                guard !local.needsUpload, item.updatedAt > (local.syncedAt ?? .distantPast) else { continue }
                local.title = item.title
                local.visibility = item.visibility
                local.updatedAt = item.updatedAt
                local.syncedAt = item.updatedAt
                try local.update(db)
                try replaceCards(of: item.id, with: item.cards, db: db)
            } else {
                let list = UserList(id: item.id, title: item.title, createdAt: item.updatedAt, enabled: true, imported: false,
                                    visibility: item.visibility, updatedAt: item.updatedAt, syncedAt: item.updatedAt)
                try list.insert(db)
                try UserLists.insertCards(item.cards, into: item.id, keepCustomIDs: true, db: db)
            }
            changed = true
        }
        let gone = try UserList.filter(Column("imported") == false && Column("synced_at") != nil).fetchAll(db)
            .filter { !remoteIDs.contains($0.id) && !$0.needsUpload }
        for list in gone {
            let cards = try UserLists.cardIDs(of: list.id, db: db)
            _ = try UserList.deleteOne(db, key: list.id)
            try UserLists.removeOrphans(cards, db: db)
            changed = true
        }
        return changed
    }

    /// After signing out: the lists stay on the device but no longer belong to an account, so a
    /// different account starts clean.
    public static func detach(db: Database) throws {
        try db.execute(sql: "UPDATE user_list SET synced_at = NULL, visibility = 'private'")
        try db.execute(sql: "DELETE FROM user_list_deleted")
    }

    private static func replaceCards(of id: String, with cards: [Card], db: Database) throws {
        let old = try UserLists.cardIDs(of: id, db: db)
        try db.execute(sql: "DELETE FROM user_list_card WHERE list_id = ?", arguments: [id])
        try UserLists.insertCards(cards, into: id, keepCustomIDs: true, db: db)
        try UserLists.removeOrphans(old, db: db)
    }
}
