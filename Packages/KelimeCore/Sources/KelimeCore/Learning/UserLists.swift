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
    /// Came from someone else's file; does not count towards the free limit.
    public var imported: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, enabled, imported
        case createdAt = "created_at"
    }
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
        let list = UserList(id: UUID().uuidString, title: title, createdAt: now, enabled: true, imported: false)
        try list.insert(db)
        return list
    }

    public static func rename(_ id: String, to title: String, db: Database) throws {
        guard var list = try UserList.fetchOne(db, key: id) else { return }
        list.title = try clean(title)
        try list.update(db)
    }

    public static func setEnabled(_ enabled: Bool, list id: String, db: Database) throws {
        guard var list = try UserList.fetchOne(db, key: id) else { return }
        list.enabled = enabled
        try list.update(db)
    }

    /// Deletes the list; the learner's own words in no other list go too.
    public static func delete(_ id: String, db: Database) throws {
        let cards = try cardIDs(of: id, db: db)
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
    public static func `import`(_ shared: SharedList, now: Date = .now, db: Database) throws -> UserList {
        let title = (try? clean(shared.title)) ?? "Paylaşılan liste"
        let list = UserList(id: UUID().uuidString, title: title, createdAt: now, enabled: true, imported: true)
        try list.insert(db)
        var position = 0
        var seen = Set<String>()
        for card in shared.cards where seen.insert(card.word.lowercased()).inserted {
            let id: String
            if !card.id.hasPrefix(customPrefix), try Card.exists(db, key: card.id) {
                id = card.id
            } else {
                var copy = card
                copy.id = customPrefix + UUID().uuidString
                copy.tr = Array(copy.tr.prefix(3))
                try copy.insert(db)
                id = copy.id
            }
            try UserListCard(listID: list.id, cardID: id, position: position).insert(db)
            position += 1
        }
        return list
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

    private static func removeOrphans(_ cardIDs: [String], db: Database) throws {
        for id in cardIDs where id.hasPrefix(customPrefix) {
            let used = try UserListCard.filter(Column("card_id") == id).fetchCount(db)
            if used == 0 { _ = try Card.deleteOne(db, key: id) }
        }
    }
}
