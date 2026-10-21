import Foundation
import GRDB

/// Maintains `widget_queue`: one row per rotation slot for the next 24 hours.
///
/// The widget timeline is built from this table. Refilling keeps existing future slots (and the
/// quiz answers stored on them), drops old ones, and picks cards for missing slots.
public enum WidgetQueue {
    /// Wrong options shown next to the answer in the medium quiz widget.
    public static let quizOptionCount = 2

    /// Past slots kept around so the "no repeat within 20 slots" rule spans refills.
    static let historyToKeep = WidgetScheduler.recentWindow

    /// Brings the queue up to date and returns the slots from the current one onward.
    @discardableResult
    public static func refill(
        db: Database,
        clock: AppClock,
        using rng: inout some RandomNumberGenerator
    ) throws -> [WidgetQueueEntry] {
        let now = clock.now
        let calendar = clock.calendar
        let prefs = try Preferences.load(db)
        let interval = prefs.effectiveRotation
        let wanted = WidgetScheduler.slots(from: now, interval: interval, calendar: calendar)
        guard let currentSlot = wanted.first else { return [] }

        try markShown(db: db, now: now)

        // A rotation change moves the slot grid; future slots on the old grid are discarded.
        let wantedSet = Set(wanted)
        let future = try WidgetQueueEntry
            .filter(WidgetQueueEntry.Columns.slotStart >= currentSlot)
            .fetchAll(db)
        for entry in future where !wantedSet.contains(entry.slotStart) {
            try entry.delete(db)
        }
        try pruneHistory(before: currentSlot, db: db)

        let existing = Set(future.map(\.slotStart)).intersection(wantedSet)
        let missing = wanted.filter { !existing.contains($0) }
        if !missing.isEmpty {
            let candidates = try CardQueries.candidates(in: prefs.entitledDecks, db: db)
            for slot in missing {
                let recent = try String.fetchAll(
                    db,
                    sql: "SELECT card_id FROM widget_queue WHERE slot_start < ? ORDER BY slot_start DESC LIMIT ?",
                    arguments: [slot, WidgetScheduler.recentWindow]
                )
                guard let cardID = WidgetScheduler.pick(from: candidates, recent: recent, now: slot, using: &rng),
                      let card = try Card.fetchOne(db, key: cardID)
                else { continue }
                let options = try CardQueries.quizOptions(for: card, optionCount: quizOptionCount, db: db, using: &rng)
                try WidgetQueueEntry(slotStart: slot, cardID: cardID, quizOptions: options).insert(db)
            }
            // The current slot may have just been created; it is already on screen.
            try markShown(db: db, now: now)
        }

        return try WidgetQueueEntry
            .filter(WidgetQueueEntry.Columns.slotStart >= currentSlot)
            .order(WidgetQueueEntry.Columns.slotStart)
            .fetchAll(db)
    }

    /// The entry for the slot containing `clock.now`, if the queue has one.
    public static func current(db: Database, clock: AppClock) throws -> WidgetQueueEntry? {
        try WidgetQueueEntry
            .filter(WidgetQueueEntry.Columns.slotStart <= clock.now)
            .order(WidgetQueueEntry.Columns.slotStart.desc)
            .fetchOne(db)
    }

    /// Stores the user's quiz answer on the current slot; it stays visible until the next slot.
    public static func recordQuizAnswer(_ option: String, slotStart: Date, db: Database) throws {
        guard var entry = try WidgetQueueEntry.fetchOne(db, key: slotStart) else { return }
        entry.quizAnswer = option
        try entry.update(db)
    }

    /// Counts slots that have started as shown: updates `last_shown_at` and `times_shown`.
    public static func markShown(db: Database, now: Date) throws {
        let started = try WidgetQueueEntry
            .filter(WidgetQueueEntry.Columns.slotStart <= now && WidgetQueueEntry.Columns.counted == false)
            .order(WidgetQueueEntry.Columns.slotStart)
            .fetchAll(db)
        for var entry in started {
            var state = try LearningStore.state(of: entry.cardID, db: db)
            state.timesShown += 1
            state.lastShownAt = max(state.lastShownAt ?? entry.slotStart, entry.slotStart)
            try state.save(db)
            entry.counted = true
            try entry.update(db)
        }
    }

    /// Clears every slot, e.g. after a settings or purchase change; the next refill rebuilds them.
    public static func clearFuture(db: Database, clock: AppClock) throws {
        try markShown(db: db, now: clock.now)
        _ = try WidgetQueueEntry.filter(WidgetQueueEntry.Columns.slotStart > clock.now).deleteAll(db)
    }

    /// Like `clearFuture`, but the word on screen goes too, so the widget changes at once
    /// (a level change). The next refill fills the current slot again.
    public static func clearCurrentAndFuture(db: Database, clock: AppClock) throws {
        try markShown(db: db, now: clock.now)
        guard let current = try current(db: db, clock: clock) else { return }
        _ = try WidgetQueueEntry.filter(WidgetQueueEntry.Columns.slotStart >= current.slotStart).deleteAll(db)
    }

    static func pruneHistory(before currentSlot: Date, db: Database) throws {
        try db.execute(
            sql: """
                DELETE FROM widget_queue WHERE slot_start < ? AND slot_start NOT IN (
                    SELECT slot_start FROM widget_queue WHERE slot_start < ? ORDER BY slot_start DESC LIMIT ?
                )
                """,
            arguments: [currentSlot, currentSlot, historyToKeep]
        )
    }
}
