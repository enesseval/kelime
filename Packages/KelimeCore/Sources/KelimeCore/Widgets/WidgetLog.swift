import Foundation
import GRDB

/// One diagnostic event for Geliştirici › Widget günlüğü.
public struct WidgetLogEntry: Codable, Sendable, Hashable, Identifiable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "widget_log"

    public enum Kind: String, Codable, Sendable, DatabaseValueConvertible {
        /// iOS asked the widget extension for a new timeline.
        case timeline
        /// The user tapped the widget, which opened the app on the word it was showing.
        case tap
        /// The user tapped Biliyorum / Zorlanıyorum / a quiz option on the widget.
        case button
        /// The app asked WidgetKit to reload (after a change in the app). Timelines that
        /// follow within seconds were requested by us, not scheduled by iOS.
        case appReload
    }

    public var id: Int64?
    public var at: Date
    public var kind: Kind
    /// Which widget: "lock", "home", "quiz"…
    public var source: String
    public var detail: String
    /// The word (and its slot, when the link carries it) the widget had on screen.
    public var shownCardID: String?
    public var shownSlot: Date?
    /// The word the schedule says should be on screen at `at`.
    public var expectedCardID: String?
    public var expectedSlot: Date?
    /// For timelines: when the widget asked iOS to come back (nil = after the last entry).
    public var reloadAt: Date?

    public init(
        id: Int64? = nil, at: Date, kind: Kind, source: String, detail: String = "",
        shownCardID: String? = nil, shownSlot: Date? = nil,
        expectedCardID: String? = nil, expectedSlot: Date? = nil, reloadAt: Date? = nil
    ) {
        self.id = id
        self.at = at
        self.kind = kind
        self.source = source
        self.detail = detail
        self.shownCardID = shownCardID
        self.shownSlot = shownSlot
        self.expectedCardID = expectedCardID
        self.expectedSlot = expectedSlot
        self.reloadAt = reloadAt
    }

    /// For taps and buttons: whether the widget showed the word it should have. Nil when
    /// there was nothing to compare.
    public var onTime: Bool? {
        guard kind == .tap || kind == .button, let shownCardID, let expectedCardID else { return nil }
        if let shownSlot, let expectedSlot { return shownSlot == expectedSlot }
        return shownCardID == expectedCardID
    }

    /// How long the correct word had been due when the widget still showed an older one.
    public var lag: TimeInterval? {
        guard onTime == false, let expectedSlot else { return nil }
        return max(0, at.timeIntervalSince(expectedSlot))
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    enum CodingKeys: String, CodingKey {
        case id, at, kind, source, detail
        case shownCardID = "shown_card_id"
        case shownSlot = "shown_slot"
        case expectedCardID = "expected_card_id"
        case expectedSlot = "expected_slot"
        case reloadAt = "reload_at"
    }
}

/// Records what iOS does with the widget, so the rotation promise can be checked on a real
/// device: timeline requests (how often iOS reloads) and taps (which entry was on screen).
public enum WidgetLog {
    /// Older rows are dropped so the table stays small.
    static let maxRows = 3000

    public static func recordTimeline(source: String, entries: Int, probe: Bool, reloadAt: Date?, db: Database, clock: AppClock) throws {
        let current = try WidgetQueue.current(db: db, clock: clock)
        var row = WidgetLogEntry(
            at: clock.now, kind: .timeline, source: source,
            detail: "\(entries) giriş" + (probe ? " · ölçüm modu" : ""),
            expectedCardID: current?.cardID, expectedSlot: current?.slotStart, reloadAt: reloadAt
        )
        try row.insert(db)
        try prune(db)
    }

    public static func recordAppReload(reason: String, db: Database, clock: AppClock) throws {
        var row = WidgetLogEntry(at: clock.now, kind: .appReload, source: "app", detail: reason)
        try row.insert(db)
        try prune(db)
    }

    /// A tap or button on the widget showing `cardID` (from the entry of `slot`, when known).
    public static func recordTap(
        kind: WidgetLogEntry.Kind = .tap, source: String, cardID: String, slot: Date?, detail: String = "",
        db: Database, clock: AppClock
    ) throws {
        let current = try WidgetQueue.current(db: db, clock: clock)
        var row = WidgetLogEntry(
            at: clock.now, kind: kind, source: source, detail: detail,
            shownCardID: cardID, shownSlot: slot,
            expectedCardID: current?.cardID, expectedSlot: current?.slotStart
        )
        try row.insert(db)
        try prune(db)
    }

    public static func recent(limit: Int = 500, db: Database) throws -> [WidgetLogEntry] {
        try WidgetLogEntry.order(Column("at").desc).limit(limit).fetchAll(db)
    }

    public static func clear(db: Database) throws {
        _ = try WidgetLogEntry.deleteAll(db)
    }

    private static func prune(_ db: Database) throws {
        try db.execute(sql: """
            DELETE FROM widget_log WHERE id NOT IN (SELECT id FROM widget_log ORDER BY at DESC LIMIT ?)
            """, arguments: [maxRows])
    }

    /// Measurement mode: only the entries of the current slot, and a reload request for the
    /// start of the next one. Without it the widget gets the whole 24 hours at once.
    public static func probeTimeline(_ snapshots: [WidgetSnapshot], now: Date) -> (entries: [WidgetSnapshot], reloadAt: Date) {
        let slots = Array(Set(snapshots.map(\.slotStart))).sorted()
        let current = slots.last { $0 <= now } ?? slots.first
        let entries = snapshots.filter { $0.slotStart == current }
        let next = slots.first { $0 > (current ?? now) } ?? now.addingTimeInterval(30 * 60)
        return (entries.isEmpty ? Array(snapshots.prefix(1)) : entries, next)
    }
}
