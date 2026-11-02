package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.WidgetContent
import com.enesseval.kilitkelime.core.model.WidgetQueueEntry
import java.time.Duration
import java.time.Instant

/**
 * Maintains `widget_queue`: one row per rotation slot for the next three days (port of
 * `WidgetQueue.swift`). The wallpaper, the widgets and the notification all read this table, so
 * every surface shows the same word.
 */
object WidgetQueue {
    const val QUIZ_OPTION_COUNT = 2
    val horizon: Duration = Duration.ofDays(3)
    private const val HISTORY_TO_KEEP = WidgetScheduler.RECENT_WINDOW

    /** Brings the queue up to date and returns the slots from the current one onward. */
    fun refill(db: SqlDb, clock: AppClock, rng: RandomSource): List<WidgetQueueEntry> = db.transaction {
        val now = clock.now
        val prefs = Preferences.load(db)
        val wanted = WidgetScheduler.slots(now, prefs.effectiveRotation, clock.zone, horizon)
        val currentSlot = wanted.firstOrNull() ?: return@transaction emptyList()

        markShown(db, now)

        // A rotation change moves the slot grid; future slots on the old grid go.
        val wantedSet = wanted.toSet()
        val future = db.query("SELECT * FROM widget_queue WHERE slot_start >= ?", listOf(currentSlot), WidgetQueueEntry::from)
        for (entry in future) {
            if (entry.slotStart !in wantedSet) db.execute("DELETE FROM widget_queue WHERE slot_start = ?", listOf(entry.slotStart))
        }
        pruneHistory(currentSlot, db)

        val existing = future.map { it.slotStart }.toSet().intersect(wantedSet)
        val missing = wanted.filter { it !in existing }
        if (missing.isNotEmpty()) {
            var candidates = CardQueries.candidates(prefs.entitledDecks, db, clock.today, prefs.widgetContent)
            if (candidates.isEmpty() && prefs.widgetContent != WidgetContent.ALL) {
                candidates = CardQueries.candidates(prefs.entitledDecks, db, clock.today)
            }
            for (slot in missing) {
                val recent = db.strings(
                    "SELECT card_id FROM widget_queue WHERE slot_start < ? ORDER BY slot_start DESC LIMIT ?",
                    listOf(slot, WidgetScheduler.RECENT_WINDOW),
                )
                val cardID = WidgetScheduler.pick(candidates, recent, slot, rng) ?: continue
                val card = CardQueries.card(cardID, db) ?: continue
                val options = CardQueries.quizOptions(card, QUIZ_OPTION_COUNT, db, rng)
                WidgetQueueEntry(slot, cardID, options).insert(db)
            }
            markShown(db, now)
        }
        db.query("SELECT * FROM widget_queue WHERE slot_start >= ? ORDER BY slot_start", listOf(currentSlot), WidgetQueueEntry::from)
    }

    /** The entry for the slot containing now. */
    fun current(db: SqlDb, clock: AppClock): WidgetQueueEntry? = db.query(
        "SELECT * FROM widget_queue WHERE slot_start <= ? ORDER BY slot_start DESC LIMIT 1",
        listOf(clock.now), WidgetQueueEntry::from,
    ).firstOrNull()

    /** The entry right before [slot] (the previous word; self-test shows its answer). */
    fun previous(slot: Instant, db: SqlDb): WidgetQueueEntry? = db.query(
        "SELECT * FROM widget_queue WHERE slot_start < ? ORDER BY slot_start DESC LIMIT 1",
        listOf(slot), WidgetQueueEntry::from,
    ).firstOrNull()

    fun entry(slot: Instant, db: SqlDb): WidgetQueueEntry? =
        db.query("SELECT * FROM widget_queue WHERE slot_start = ?", listOf(slot), WidgetQueueEntry::from).firstOrNull()

    fun recordQuizAnswer(option: String, slotStart: Instant, db: SqlDb) {
        db.execute("UPDATE widget_queue SET quiz_answer = ? WHERE slot_start = ?", listOf(option, slotStart))
    }

    /** Counts started slots as shown: `last_shown_at` and `times_shown`. */
    fun markShown(db: SqlDb, now: Instant) {
        val started = db.query(
            "SELECT * FROM widget_queue WHERE slot_start <= ? AND counted = 0 ORDER BY slot_start",
            listOf(now), WidgetQueueEntry::from,
        )
        for (entry in started) {
            val state = LearningStore.state(entry.cardID, db)
            val last = state.lastShownAt ?: entry.slotStart
            state.copy(timesShown = state.timesShown + 1, lastShownAt = maxOf(last, entry.slotStart)).save(db)
            db.execute("UPDATE widget_queue SET counted = 1 WHERE slot_start = ?", listOf(entry.slotStart))
            db.execute("INSERT OR REPLACE INTO widget_shown (slot_start, card_id) VALUES (?, ?)", listOf(entry.slotStart, entry.cardID))
        }
    }

    /** Clears future slots (settings or purchase change). */
    fun clearFuture(db: SqlDb, clock: AppClock) {
        markShown(db, clock.now)
        db.execute("DELETE FROM widget_queue WHERE slot_start > ?", listOf(clock.now))
    }

    /** Like [clearFuture] but the word on screen goes too (a level change). */
    fun clearCurrentAndFuture(db: SqlDb, clock: AppClock) {
        markShown(db, clock.now)
        val current = current(db, clock) ?: return
        db.execute("DELETE FROM widget_queue WHERE slot_start >= ?", listOf(current.slotStart))
    }

    internal fun pruneHistory(currentSlot: Instant, db: SqlDb) {
        db.execute(
            """DELETE FROM widget_queue WHERE slot_start < ? AND slot_start NOT IN (
                 SELECT slot_start FROM widget_queue WHERE slot_start < ? ORDER BY slot_start DESC LIMIT ?)""",
            listOf(currentSlot, currentSlot, HISTORY_TO_KEEP),
        )
    }
}
