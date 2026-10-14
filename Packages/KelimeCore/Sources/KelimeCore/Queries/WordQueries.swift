import Foundation
import GRDB

/// A card with the user's progress, for lists and the word detail screen.
public struct WordItem: Sendable, Equatable, Identifiable {
    public var card: Card
    public var state: LearningState
    public var favorite: Bool
    public var tags: [DeckTag]

    public var id: String { card.id }

    /// Deck chip on the word detail screen: the first exam deck, else "Genel".
    public var deckLabel: String {
        if tags.contains(.yds) { return DeckID.yds.rawValue }
        if tags.contains(.yokdil) { return DeckID.yokdil.rawValue }
        if tags.contains(.ielts) { return DeckID.ielts.rawValue }
        return "Genel"
    }
}

/// Segments of Kelimelerim.
public enum WordSegment: String, CaseIterable, Sendable {
    case struggling
    case learned
    case favorites
    case all

    public var label: String {
        switch self {
        case .struggling: "Zorlanılan"
        case .learned: "Öğrenildi"
        case .favorites: "Favoriler"
        case .all: "Tümü"
        }
    }

    /// Empty-state copy for this segment.
    public var emptyText: String {
        switch self {
        case .struggling: "Zorlandığın kelime yok. Bir Hızlı Tekrar ile başla."
        case .learned: "Henüz öğrendiğin kelime yok. Bir Hızlı Tekrar ile başla."
        case .favorites: "Favori kelimen yok. Kelime detayında yıldıza dokun."
        case .all: "Aramana uyan kelime yok."
        }
    }
}

public enum WordQueries {
    public static func item(id: String, db: Database) throws -> WordItem? {
        guard let card = try Card.fetchOne(db, key: id) else { return nil }
        let state = try CardState.fetchOne(db, key: id)
        let tags = try DeckTag.fetchAll(db, sql: "SELECT deck FROM card_deck WHERE card_id = ? ORDER BY deck", arguments: [id])
        return WordItem(card: card, state: state?.state ?? .new, favorite: state?.favorite ?? false, tags: tags)
    }

    /// Words for a Kelimelerim segment, filtered by `search` over the English word and the
    /// Turkish meaning (Turkish-aware, case- and diacritic-insensitive), sorted alphabetically.
    public static func list(segment: WordSegment, search: String = "", db: Database) throws -> [WordItem] {
        var sql = """
            SELECT c.*, COALESCE(s.state, 'new') AS user_state, COALESCE(s.favorite, 0) AS user_favorite
            FROM card c LEFT JOIN card_state s ON s.card_id = c.id
            """
        switch segment {
        case .struggling: sql += " WHERE s.state = 'struggling'"
        case .learned: sql += " WHERE s.state = 'learned'"
        case .favorites: sql += " WHERE s.favorite = 1"
        case .all: break
        }
        sql += " ORDER BY c.word"
        let rows = try Row.fetchAll(db, sql: sql)
        let needle = normalize(search)
        return try rows.compactMap { row -> WordItem? in
            let card = try Card(row: row)
            if !needle.isEmpty, !normalize(card.word).contains(needle), !normalize(card.meaning).contains(needle) {
                return nil
            }
            return WordItem(
                card: card,
                state: LearningState(rawValue: row["user_state"]) ?? .new,
                favorite: row["user_favorite"],
                tags: []
            )
        }
    }

    /// Lowercases with Turkish rules and strips diacritics, so "IŞIK", "ışık" and "isik" match.
    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "tr_TR"))
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
    }
}

/// Progress of one deck card on the Desteler view.
public struct DeckProgress: Sendable, Equatable, Identifiable {
    public var deck: DeckID
    public var total: Int
    public var learned: Int
    public var enabled: Bool
    public var locked: Bool

    public var id: String { deck.rawValue }
    public var fraction: Double { total == 0 ? 0 : Double(learned) / Double(total) }
    public var isFinished: Bool { total > 0 && learned == total }
}

public enum DeckQueries {
    public static func progress(db: Database) throws -> [DeckProgress] {
        let prefs = try Preferences.load(db)
        return try DeckID.allCases.map { deck in
            guard let filter = CardQueries.deckFilter([deck]) else {
                return DeckProgress(deck: deck, total: 0, learned: 0, enabled: false, locked: deck.isPro && !prefs.isPro)
            }
            let row = try Row.fetchOne(db, SQLRequest<Row>("""
                SELECT COUNT(*) AS total, SUM(CASE WHEN s.state = 'learned' THEN 1 ELSE 0 END) AS learned
                FROM card c LEFT JOIN card_state s ON s.card_id = c.id
                WHERE \(filter)
                """))
            return DeckProgress(
                deck: deck,
                total: row?["total"] ?? 0,
                learned: row?["learned"] ?? 0,
                enabled: prefs.enabledDecks.contains(deck),
                locked: deck.isPro && !prefs.isPro
            )
        }
    }

    /// Turns "widget'ta göster" on or off for a deck. Locked decks are left unchanged.
    @discardableResult
    public static func setEnabled(_ enabled: Bool, deck: DeckID, db: Database) throws -> Bool {
        var prefs = try Preferences.load(db)
        guard !deck.isPro || prefs.isPro else { return false }
        if enabled {
            if !prefs.enabledDecks.contains(deck) { prefs.enabledDecks.append(deck) }
        } else {
            prefs.enabledDecks.removeAll { $0 == deck }
        }
        try prefs.save(db)
        return true
    }
}
