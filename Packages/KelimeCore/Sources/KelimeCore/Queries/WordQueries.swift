import Foundation
import GRDB

/// A card with the user's progress, for lists and the word detail screen.
public struct WordItem: Sendable, Equatable, Identifiable {
    public var card: Card
    public var state: LearningState
    public var favorite: Bool
    public var tags: [DeckTag]
    /// For a learned word, the day it comes back for review.
    public var nextReview: LocalDate?

    public var id: String { card.id }

    /// Deck chip on the word detail screen: the first exam deck, else "Genel".
    public var deckLabel: String {
        if card.id.hasPrefix(UserLists.customPrefix) { return "Kendi kelimen" }
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
        case .all: "Aramana ya da filtrelerine uyan kelime yok."
        }
    }
}

/// Orders of the Kelimelerim lists.
public enum WordSort: String, CaseIterable, Sendable {
    case alphabetical
    case reverseAlphabetical
    case level
    case recentlyStudied
    case mostMissed

    public var label: String {
        switch self {
        case .alphabetical: "A–Z"
        case .reverseAlphabetical: "Z–A"
        case .level: "Seviye"
        case .recentlyStudied: "Son çalışılan"
        case .mostMissed: "En çok yanlış"
        }
    }

    var orderBy: String {
        switch self {
        case .alphabetical: "c.word COLLATE NOCASE"
        case .reverseAlphabetical: "c.word COLLATE NOCASE DESC"
        case .level: "c.level, c.word COLLATE NOCASE"
        case .recentlyStudied: "last_studied IS NULL, last_studied DESC, c.word COLLATE NOCASE"
        case .mostMissed: "missed DESC, c.word COLLATE NOCASE"
        }
    }
}

/// Kinds of word for the Tümü filter, grouping the parts of speech.
public enum WordKind: String, CaseIterable, Sendable, Hashable {
    case noun, verb, adjective, adverb, phrase, other

    public var label: String {
        switch self {
        case .noun: "İsim"
        case .verb: "Fiil"
        case .adjective: "Sıfat"
        case .adverb: "Zarf"
        case .phrase: "Kalıp"
        case .other: "Diğer"
        }
    }

    var partsOfSpeech: [PartOfSpeech] {
        switch self {
        case .noun: [.noun]
        case .verb: [.verb]
        case .adjective: [.adjective]
        case .adverb: [.adverb]
        case .phrase: [.phrase]
        case .other: [.preposition, .conjunction]
        }
    }
}

/// Filters of the Tümü list. Empty sets filter nothing.
public struct WordFilter: Sendable, Equatable {
    public var levels: Set<CEFRLevel> = []
    public var states: Set<LearningState> = []
    public var kinds: Set<WordKind> = []

    public init(levels: Set<CEFRLevel> = [], states: Set<LearningState> = [], kinds: Set<WordKind> = []) {
        self.levels = levels
        self.states = states
        self.kinds = kinds
    }

    public var isEmpty: Bool { levels.isEmpty && states.isEmpty && kinds.isEmpty }
    public var count: Int { levels.count + states.count + kinds.count }
}

public enum WordQueries {
    public static func item(id: String, db: Database) throws -> WordItem? {
        guard let card = try Card.fetchOne(db, key: id) else { return nil }
        let state = try CardState.fetchOne(db, key: id)
        let tags = try DeckTag.fetchAll(db, sql: "SELECT deck FROM card_deck WHERE card_id = ? ORDER BY deck", arguments: [id])
        return WordItem(card: card, state: state?.state ?? .new, favorite: state?.favorite ?? false, tags: tags,
                        nextReview: state.flatMap(SpacedReview.dueDate))
    }

    /// Words for a Kelimelerim segment, filtered by `search` over the English word and the
    /// Turkish meaning (Turkish-aware, case- and diacritic-insensitive).
    ///
    /// Tümü holds the words the learner has met: the cards of started units (the core of the
    /// current level counts as started) and every card with progress or a star. Words of units
    /// not started yet and untouched exam cards stay out. `filter` applies to every segment.
    public static func list(
        segment: WordSegment,
        search: String = "",
        filter: WordFilter = WordFilter(),
        sort: WordSort = .alphabetical,
        db: Database
    ) throws -> [WordItem] {
        var conditions: [String] = []
        var arguments: [any DatabaseValueConvertible] = []
        switch segment {
        case .struggling: conditions.append("s.state = 'struggling'")
        case .learned: conditions.append("s.state = 'learned'")
        case .favorites: conditions.append("s.favorite = 1")
        case .all:
            let level = try Preferences.load(db).level
            let saved = (try Settings.string(.unitsStarted, in: db) ?? "").split(separator: ",").map(String.init)
            let units = saved + (try String.fetchAll(db, sql: "SELECT id FROM unit WHERE placement = ? AND level = ?", arguments: [UnitPlacement.first, level]))
            let marks = units.isEmpty ? "NULL" : Array(repeating: "?", count: units.count).joined(separator: ",")
            conditions.append("""
                (EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id AND uc.unit_id IN (\(marks)))
                 OR EXISTS (SELECT 1 FROM user_list_card ulc WHERE ulc.card_id = c.id)
                 OR s.state IN ('struggling', 'learned') OR s.favorite = 1)
                """)
            arguments += units
        }
        if !filter.levels.isEmpty {
            conditions.append("c.level IN (\(Array(repeating: "?", count: filter.levels.count).joined(separator: ",")))")
            arguments += filter.levels.sorted().map(\.rawValue)
        }
        if !filter.states.isEmpty {
            conditions.append("COALESCE(s.state, 'new') IN (\(Array(repeating: "?", count: filter.states.count).joined(separator: ",")))")
            arguments += filter.states.map(\.rawValue).sorted()
        }
        if !filter.kinds.isEmpty {
            let poses = filter.kinds.flatMap(\.partsOfSpeech).map(\.rawValue).sorted()
            conditions.append("c.pos IN (\(Array(repeating: "?", count: poses.count).joined(separator: ",")))")
            arguments += poses
        }
        let sql = """
            SELECT c.*, COALESCE(s.state, 'new') AS user_state, COALESCE(s.favorite, 0) AS user_favorite,
                (SELECT MAX(r.answered_at) FROM review_log r WHERE r.card_id = c.id) AS last_studied,
                (SELECT COUNT(*) FROM review_log r WHERE r.card_id = c.id AND r.correct = 0) AS missed
            FROM card c LEFT JOIN card_state s ON s.card_id = c.id
            \(conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND "))
            ORDER BY \(sort.orderBy)
            """
        let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
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

    public var id: String { deck.rawValue }
    public var fraction: Double { total == 0 ? 0 : Double(learned) / Double(total) }
    public var isFinished: Bool { total > 0 && learned == total }
}

public enum DeckQueries {
    public static func progress(db: Database) throws -> [DeckProgress] {
        let prefs = try Preferences.load(db)
        return try DeckID.allCases.map { deck in
            guard let filter = CardQueries.deckFilter([deck]) else {
                return DeckProgress(deck: deck, total: 0, learned: 0, enabled: false)
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
                enabled: prefs.enabledDecks.contains(deck)
            )
        }
    }

    /// Turns "widget'ta göster" on or off for a deck.
    public static func setEnabled(_ enabled: Bool, deck: DeckID, db: Database) throws {
        var prefs = try Preferences.load(db)
        if enabled {
            if !prefs.enabledDecks.contains(deck) { prefs.enabledDecks.append(deck) }
        } else {
            prefs.enabledDecks.removeAll { $0 == deck }
        }
        try prefs.save(db)
    }
}
