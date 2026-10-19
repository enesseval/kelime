import Foundation
import GRDB

/// A short story at the end of a unit: English lines with their Turkish.
public struct UnitStory: Codable, Sendable, Hashable, Identifiable {
    public struct Line: Codable, Sendable, Hashable {
        public var en: String
        public var tr: String

        public init(en: String, tr: String) {
            self.en = en
            self.tr = tr
        }
    }

    public var id: String
    public var title: String
    public var lines: [Line]

    public init(id: String, title: String, lines: [Line]) {
        self.id = id
        self.title = title
        self.lines = lines
    }
}

/// Where a unit sits in its level's course.
public enum UnitPlacement: String, Codable, Sendable, DatabaseValueConvertible {
    /// Everyone studies it first (the core).
    case first
    /// Any order after the core.
    case any
    /// After the others (the bridge to the next level).
    case last
}

/// One unit of a level's course: a goal, its cards (by `unit_card`) and its stories.
public struct CurriculumUnit: Codable, Sendable, Hashable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "unit"

    public var id: String
    public var level: CEFRLevel
    public var title: String
    public var goal: String
    public var placement: UnitPlacement
    public var position: Int
    public var stories: [UnitStory]

    public init(id: String, level: CEFRLevel, title: String, goal: String, placement: UnitPlacement, position: Int, stories: [UnitStory]) {
        self.id = id
        self.level = level
        self.title = title
        self.goal = goal
        self.placement = placement
        self.position = position
        self.stories = stories
    }
}

/// Membership of a card in a unit, in the unit's order.
struct UnitCard: Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "unit_card"
    var unitID: String
    var cardID: String
    var position: Int

    enum CodingKeys: String, CodingKey {
        case unitID = "unit_id"
        case cardID = "card_id"
        case position
    }
}

/// A unit as written in `cards.json`: the unit plus its card ids in order.
public struct ContentUnit: Codable, Sendable {
    public var unit: CurriculumUnit
    public var cards: [String]

    enum CodingKeys: String, CodingKey { case cards }

    public init(unit: CurriculumUnit, cards: [String]) {
        self.unit = unit
        self.cards = cards
    }

    public init(from decoder: Decoder) throws {
        unit = try CurriculumUnit(from: decoder)
        cards = try decoder.container(keyedBy: CodingKeys.self).decode([String].self, forKey: .cards)
    }

    public func encode(to encoder: Encoder) throws {
        try unit.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cards, forKey: .cards)
    }
}

/// A unit with the learner's progress, for the course screens.
public struct UnitProgress: Sendable, Equatable, Identifiable {
    public var unit: CurriculumUnit
    public var total: Int
    public var learned: Int
    public var started: Bool

    public var id: String { unit.id }
    public var fraction: Double { total == 0 ? 0 : Double(learned) / Double(total) }
    public var isFinished: Bool { total > 0 && learned == total }
}

/// The course: units per level, which ones the learner started, and their cards.
public enum Curriculum {
    /// Units of `level` in course order (core first, bridge last).
    public static func units(level: CEFRLevel, db: Database) throws -> [CurriculumUnit] {
        try CurriculumUnit.filter(Column("level") == level).order(Column("position")).fetchAll(db)
    }

    /// Started unit ids. Core units always count as started, so a learner who opens the A1
    /// course gets the core words on the widget right away.
    public static func started(db: Database) throws -> Set<String> {
        let saved = (try Settings.string(.unitsStarted, in: db) ?? "")
            .split(separator: ",").map(String.init)
        let core = try String.fetchAll(db, sql: "SELECT id FROM unit WHERE placement = ?", arguments: [UnitPlacement.first])
        return Set(saved).union(core)
    }

    /// Starts `unitID`: its cards join the widget, and its level deck is switched on.
    public static func start(_ unitID: String, db: Database) throws {
        guard let unit = try CurriculumUnit.fetchOne(db, key: unitID) else { return }
        var saved = (try Settings.string(.unitsStarted, in: db) ?? "").split(separator: ",").map(String.init)
        if !saved.contains(unitID) {
            saved.append(unitID)
            try Settings.set(.unitsStarted, saved.joined(separator: ","), in: db)
        }
        var prefs = try Preferences.load(db)
        if let deck = DeckID.allCases.first(where: { $0.level == unit.level }), !prefs.enabledDecks.contains(deck) {
            prefs.enabledDecks.append(deck)
            try prefs.save(db)
        }
    }

    /// The unit's cards in order.
    public static func cards(of unitID: String, db: Database) throws -> [Card] {
        try Card.fetchAll(db, sql: """
            SELECT c.* FROM card c JOIN unit_card u ON u.card_id = c.id
            WHERE u.unit_id = ? ORDER BY u.position
            """, arguments: [unitID])
    }

    public static func progress(level: CEFRLevel, db: Database) throws -> [UnitProgress] {
        let started = try started(db: db)
        return try units(level: level, db: db).map { unit in
            let row = try Row.fetchOne(db, sql: """
                SELECT COUNT(*) AS total, SUM(CASE WHEN s.state = 'learned' THEN 1 ELSE 0 END) AS learned
                FROM unit_card u LEFT JOIN card_state s ON s.card_id = u.card_id
                WHERE u.unit_id = ?
                """, arguments: [unit.id])
            return UnitProgress(unit: unit, total: row?["total"] ?? 0, learned: row?["learned"] ?? 0,
                                started: started.contains(unit.id))
        }
    }

    /// SQL condition on `card c`: cards outside the course, or in a started unit. Units the
    /// learner has not started stay off the widget and out of Quick Review.
    static func startedFilter(db: Database) throws -> SQL {
        let started = Array(try started(db: db))
        return """
            (NOT EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id)
             OR EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id AND uc.unit_id IN \(started)))
            """
    }

    /// Replaces every unit with `units` (part of a content import).
    static func replace(with units: [ContentUnit], db: Database) throws {
        _ = try UnitCard.deleteAll(db)
        _ = try CurriculumUnit.deleteAll(db)
        for item in units {
            try item.unit.insert(db)
            for (position, cardID) in item.cards.enumerated() {
                try UnitCard(unitID: item.unit.id, cardID: cardID, position: position).insert(db)
            }
        }
    }
}
