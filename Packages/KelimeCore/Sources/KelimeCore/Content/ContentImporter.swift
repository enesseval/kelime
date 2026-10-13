import Foundation
import GRDB

/// Shape of `Content/cards.json`.
public struct CardsFile: Codable, Sendable {
    public var contentVersion: Int
    public var cards: [ContentCard]
}

/// A card as written in `cards.json`: the card plus its tag decks.
public struct ContentCard: Codable, Sendable {
    public var card: Card
    public var decks: [DeckTag]

    public init(card: Card, decks: [DeckTag]) {
        self.card = card
        self.decks = decks
    }

    enum CodingKeys: String, CodingKey { case decks }

    public init(from decoder: Decoder) throws {
        card = try Card(from: decoder)
        decks = try decoder.container(keyedBy: CodingKeys.self).decode([DeckTag].self, forKey: .decks)
    }

    public func encode(to encoder: Encoder) throws {
        try card.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(decks, forKey: .decks)
    }
}

public enum ImportResult: Equatable, Sendable {
    case upToDate(version: Int)
    case imported(version: Int, cardCount: Int)
}

/// Imports bundled cards into the shared database.
///
/// Runs on first launch and whenever `contentVersion` changes. Cards are upserted by `id` in a
/// single transaction; user progress (`card_state`, logs, puzzles) is never touched.
public enum ContentImporter {
    public static func decode(_ data: Data) throws -> CardsFile {
        try JSONDecoder().decode(CardsFile.self, from: data)
    }

    /// Imports `data` unless the database already holds the same content version.
    /// `progress` receives values from 0 to 1 and may be called from any thread.
    public static func importIfNeeded(
        _ data: Data,
        into database: AppDatabase,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> ImportResult {
        let file = try decode(data)
        let current = try await database.reader.read { db in
            try Settings.int(.contentVersion, in: db)
        }
        if current == file.contentVersion, try database.hasContent() {
            progress(1)
            return .upToDate(version: file.contentVersion)
        }

        try await database.writer.write { db in
            try apply(file, in: db, progress: progress)
        }
        return .imported(version: file.contentVersion, cardCount: file.cards.count)
    }

    static func apply(_ file: CardsFile, in db: Database, progress: @Sendable (Double) -> Void) throws {
        let incomingIDs = Set(file.cards.map(\.card.id))
        let existingIDs = try Set(String.fetchAll(db, sql: "SELECT id FROM card"))

        // Cards dropped from the content disappear from rotation; their progress rows stay.
        let removed = existingIDs.subtracting(incomingIDs)
        if !removed.isEmpty {
            _ = try Card.filter(keys: Array(removed)).deleteAll(db)
        }

        let total = max(file.cards.count, 1)
        let step = max(total / 50, 1)
        for (index, item) in file.cards.enumerated() {
            try item.card.upsert(db)
            try db.execute(sql: "DELETE FROM card_deck WHERE card_id = ?", arguments: [item.card.id])
            for deck in Set(item.decks) {
                try CardDeck(cardID: item.card.id, deck: deck).insert(db)
            }
            if index % step == 0 {
                progress(Double(index) / Double(total))
            }
        }

        try Settings.set(.contentVersion, file.contentVersion, in: db)
        progress(1)
    }
}
