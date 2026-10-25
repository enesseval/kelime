import Foundation
import GRDB

/// One of the learner's own word lists.
public struct UserList: Codable, Sendable, Hashable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "user_list"

    public var id: String
    public var title: String
    public var createdAt: Date
    /// On the widget and in Quick Review.
    public var enabled: Bool
    /// Came from someone else's file or Keşfet; does not count towards the free limit and is
    /// not synced to the account.
    public var imported: Bool
    /// Who may open it once synced: private, link or public (Keşfet).
    public var visibility: ListVisibility = .private
    /// Last change on this device (title, words, visibility); nil before the first change.
    public var updatedAt: Date?
    /// The server's `updated_at` when this list last matched it; nil if never synced.
    public var syncedAt: Date?
    /// The Keşfet list this one was saved from.
    public var sourceID: String?

    public init(id: String, title: String, createdAt: Date, enabled: Bool, imported: Bool, visibility: ListVisibility = .private, updatedAt: Date? = nil, syncedAt: Date? = nil, sourceID: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.enabled = enabled
        self.imported = imported
        self.visibility = visibility
        self.updatedAt = updatedAt
        self.syncedAt = syncedAt
        self.sourceID = sourceID
    }

    /// Changed here since it last matched the server.
    public var needsUpload: Bool {
        guard !imported else { return false }
        guard let syncedAt else { return true }
        return (updatedAt ?? .distantPast) > syncedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, enabled, imported, visibility
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncedAt = "synced_at"
        case sourceID = "source_id"
    }
}

public enum ListVisibility: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case `private`, link, `public`
}

struct UserListCard: Codable, Sendable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_list_card"
    var listID: String
    var cardID: String
    var position: Int

    enum CodingKeys: String, CodingKey {
        case listID = "list_id"
        case cardID = "card_id"
        case position
    }
}

/// A list with its counts, for the Listeler screen.
public struct UserListSummary: Sendable, Equatable, Identifiable {
    public var list: UserList
    public var total: Int
    public var learned: Int

    public var id: String { list.id }
    public var fraction: Double { total == 0 ? 0 : Double(learned) / Double(total) }
}

/// A list as it travels in a shared file: its title and full cards, so it opens on any device.
public struct SharedList: Codable, Sendable, Equatable {
    public static let fileExtension = "kelimelist"
    public var format = 1
    public var title: String
    public var cards: [Card]

    public init(title: String, cards: [Card]) {
        self.title = title
        self.cards = cards
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> SharedList {
        try JSONDecoder().decode(SharedList.self, from: data)
    }
}

public enum UserListError: Error, Equatable {
    /// Free users have one list of their own; more need Pro.
    case limitReached
    case emptyTitle
    case emptyWord
    case duplicateWord
    case unreadableFile
}

/// The learner's own lists: create, fill, switch on for the widget, share and import.
public enum UserLists {
    /// Ids of the words the learner types; content updates never touch them.
    public static let customPrefix = "user-"
    /// Own lists a free user may create (imported ones do not count).
    public static let freeLimit = 1
    public static let maxTitle = 40

    public static func summaries(db: Database) throws -> [UserListSummary] {
        let lists = try UserList.order(Column("created_at")).fetchAll(db)
        return try lists.map { list in
            let row = try Row.fetchOne(db, sql: """
                SELECT COUNT(*) AS total, SUM(CASE WHEN s.state = 'learned' THEN 1 ELSE 0 END) AS learned
                FROM user_list_card l LEFT JOIN card_state s ON s.card_id = l.card_id
                WHERE l.list_id = ?
                """, arguments: [list.id])
            return UserListSummary(list: list, total: row?["total"] ?? 0, learned: row?["learned"] ?? 0)
        }
    }

    public static func list(id: String, db: Database) throws -> UserList? {
        try UserList.fetchOne(db, key: id)
    }

    /// Whether a free user may create another list.
    public static func canCreate(isPro: Bool, db: Database) throws -> Bool {
        if isPro { return true }
        return try UserList.filter(Column("imported") == false).fetchCount(db) < freeLimit
    }

    @discardableResult
    public static func create(title: String, isPro: Bool, now: Date = .now, db: Database) throws -> UserList {
        let title = try clean(title)
        guard try canCreate(isPro: isPro, db: db) else { throw UserListError.limitReached }
        let list = UserList(id: UUID().uuidString.lowercased(), title: title, createdAt: now, enabled: true, imported: false, updatedAt: now)
        try list.insert(db)
        return list
    }

    public static func rename(_ id: String, to title: String, db: Database) throws {
        guard var list = try UserList.fetchOne(db, key: id) else { return }
        list.title = try clean(title)
        list.updatedAt = .now
        try list.update(db)
    }

    /// Who may open the list once it is synced.
    public static func setVisibility(_ visibility: ListVisibility, list id: String, db: Database) throws {
        guard var list = try UserList.fetchOne(db, key: id), list.visibility != visibility else { return }
        list.visibility = visibility
        list.updatedAt = .now
        try list.update(db)
    }

    /// Marks the list changed here, so the next sync uploads it.
    static func touch(_ id: String, db: Database) throws {
        try db.execute(sql: "UPDATE user_list SET updated_at = ? WHERE id = ?", arguments: [Date.now, id])
    }

    public static func setEnabled(_ enabled: Bool, list id: String, db: Database) throws {
        guard var list = try UserList.fetchOne(db, key: id) else { return }
        list.enabled = enabled
        try list.update(db)
    }

    /// Deletes the list; the learner's own words in no other list go too.
    public static func delete(_ id: String, db: Database) throws {
        let cards = try cardIDs(of: id, db: db)
        // A list the server has must be deleted there too, at the next sync.
        if let list = try UserList.fetchOne(db, key: id), list.syncedAt != nil {
            try db.execute(sql: "INSERT OR IGNORE INTO user_list_deleted (id) VALUES (?)", arguments: [id])
        }
        _ = try UserList.deleteOne(db, key: id)
        try removeOrphans(cards, db: db)
    }

    /// Cards of the list, in the order they were added.
    public static func cards(of id: String, db: Database) throws -> [Card] {
        try Card.fetchAll(db, sql: """
            SELECT c.* FROM card c JOIN user_list_card l ON l.card_id = c.id
            WHERE l.list_id = ? ORDER BY l.position
            """, arguments: [id])
    }

    static func cardIDs(of id: String, db: Database) throws -> [String] {
        try String.fetchAll(db, sql: "SELECT card_id FROM user_list_card WHERE list_id = ? ORDER BY position", arguments: [id])
    }

    /// Adds an existing card (a course or exam word, or the learner's own) to the list.
    public static func add(cardID: String, to id: String, db: Database) throws {
        guard try Card.exists(db, key: cardID) else { return }
        guard try UserListCard.filter(Column("list_id") == id && Column("card_id") == cardID).fetchCount(db) == 0 else {
            throw UserListError.duplicateWord
        }
        let next = (try Int.fetchOne(db, sql: "SELECT MAX(position) FROM user_list_card WHERE list_id = ?", arguments: [id]) ?? -1) + 1
        try UserListCard(listID: id, cardID: cardID, position: next).insert(db)
        try touch(id, db: db)
    }

    /// Adds a word the learner typed. `level` is only used to pick wrong options in quizzes.
    @discardableResult
    public static func addCustom(
        word: String, meaning: String, pos: PartOfSpeech,
        exampleEN: String = "", exampleTR: String = "",
        level: CEFRLevel, to id: String, db: Database
    ) throws -> Card {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let meanings = meaning.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !word.isEmpty, !meanings.isEmpty else { throw UserListError.emptyWord }
        let existing = try cards(of: id, db: db)
        guard !existing.contains(where: { $0.word.lowercased() == word.lowercased() }) else { throw UserListError.duplicateWord }
        let card = Card(
            id: customPrefix + UUID().uuidString,
            word: word,
            pos: word.contains(" ") && pos != .phrase ? .phrase : pos,
            level: level,
            tr: Array(meanings.prefix(3)),
            exampleEN: exampleEN.trimmingCharacters(in: .whitespacesAndNewlines),
            exampleTR: exampleTR.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try card.insert(db)
        try add(cardID: card.id, to: id, db: db)
        return card
    }

    /// Removes a card from the list; the learner's own word goes if no other list holds it.
    public static func remove(cardID: String, from id: String, db: Database) throws {
        _ = try UserListCard.filter(Column("list_id") == id && Column("card_id") == cardID).deleteAll(db)
        try touch(id, db: db)
        try removeOrphans([cardID], db: db)
    }

    /// The list as a file to share.
    public static func export(_ id: String, db: Database) throws -> SharedList? {
        guard let list = try UserList.fetchOne(db, key: id) else { return nil }
        return SharedList(title: list.title, cards: try cards(of: id, db: db))
    }

    /// Adds a shared list. Words the app already has link to its cards (with their progress);
    /// other words become the learner's own. Importing is free and does not count as a list.
    @discardableResult
    public static func `import`(_ shared: SharedList, sourceID: String? = nil, now: Date = .now, db: Database) throws -> UserList {
        let title = (try? clean(shared.title)) ?? "Paylaşılan liste"
        let list = UserList(id: UUID().uuidString.lowercased(), title: title, createdAt: now, enabled: true, imported: true, sourceID: sourceID)
        try list.insert(db)
        try insertCards(shared.cards, into: list.id, keepCustomIDs: false, db: db)
        return list
    }

    /// Whether a Keşfet list was already saved here.
    public static func savedCopy(of sourceID: String, db: Database) throws -> UserList? {
        try UserList.filter(Column("source_id") == sourceID).fetchOne(db)
    }

    /// Fills a list with shared cards. Words the app has link to its cards; others become the
    /// learner's own, under a new id unless `keepCustomIDs` (the learner's own lists coming back
    /// from the account keep theirs, so the next upload sends the same ids).
    static func insertCards(_ cards: [Card], into listID: String, keepCustomIDs: Bool, db: Database) throws {
        var position = 0
        var seen = Set<String>()
        for card in cards where seen.insert(card.word.lowercased()).inserted {
            let id: String
            if !card.id.hasPrefix(customPrefix), try Card.exists(db, key: card.id) {
                id = card.id
            } else if keepCustomIDs, card.id.hasPrefix(customPrefix) {
                var copy = card
                copy.tr = Array(copy.tr.prefix(3))
                try copy.save(db)
                id = copy.id
            } else {
                var copy = card
                copy.id = customPrefix + UUID().uuidString
                copy.tr = Array(copy.tr.prefix(3))
                try copy.insert(db)
                id = copy.id
            }
            try UserListCard(listID: listID, cardID: id, position: position).insert(db)
            position += 1
        }
    }

    /// Course and exam words matching `search`, for adding to a list (English word or meaning).
    public static func suggestions(_ search: String, limit: Int = 30, db: Database) throws -> [Card] {
        let needle = WordQueries.normalize(search)
        guard !needle.isEmpty else { return [] }
        let cards = try Card.filter(!Column("id").like(customPrefix + "%")).order(Column("word")).fetchAll(db)
        let starts = cards.filter { WordQueries.normalize($0.word).hasPrefix(needle) }
        let rest = cards.filter { card in
            !WordQueries.normalize(card.word).hasPrefix(needle)
                && (WordQueries.normalize(card.word).contains(needle) || WordQueries.normalize(card.meaning).contains(needle))
        }
        return Array((starts + rest).prefix(limit))
    }

    /// SQL condition: the card is in a list that is on.
    static let enabledListsCondition: SQL = """
        EXISTS (SELECT 1 FROM user_list_card ulc JOIN user_list ul ON ul.id = ulc.list_id
                WHERE ulc.card_id = c.id AND ul.enabled = 1)
        """

    public static func hasEnabledLists(db: Database) throws -> Bool {
        try Bool.fetchOne(db, sql: """
            SELECT EXISTS (SELECT 1 FROM user_list ul JOIN user_list_card c ON c.list_id = ul.id WHERE ul.enabled = 1)
            """) ?? false
    }

    private static func clean(_ title: String) throws -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw UserListError.emptyTitle }
        return String(title.prefix(maxTitle))
    }

    static func removeOrphans(_ cardIDs: [String], db: Database) throws {
        for id in cardIDs where id.hasPrefix(customPrefix) {
            let used = try UserListCard.filter(Column("card_id") == id).fetchCount(db)
            if used == 0 { _ = try Card.deleteOne(db, key: id) }
        }
    }
}
