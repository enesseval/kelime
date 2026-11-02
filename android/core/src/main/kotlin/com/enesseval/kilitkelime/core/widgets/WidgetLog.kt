package com.enesseval.kilitkelime.core.widgets

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import java.time.Duration
import java.time.Instant

/** One diagnostic event (Geliştirici › Widget günlüğü). */
data class WidgetLogEntry(
    val id: Long? = null,
    val at: Instant,
    val kind: Kind,
    /** Which surface: "wallpaper", "notification", "card", "quiz", "large"… */
    val source: String,
    val detail: String = "",
    val shownCardID: String? = null,
    val shownSlot: Instant? = null,
    val expectedCardID: String? = null,
    val expectedSlot: Instant? = null,
    val reloadAt: Instant? = null,
) {
    enum class Kind(val raw: String) {
        /** A surface was redrawn (iOS: a timeline request; Android: a wallpaper/widget update). */
        TIMELINE("timeline"),
        TAP("tap"),
        BUTTON("button"),
        APP_RELOAD("appReload");

        companion object {
            fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } ?: TIMELINE
        }
    }

    /** Whether the surface showed the word it should have; null when nothing to compare. */
    val onTime: Boolean?
        get() {
            if (shownCardID == null || expectedCardID == null) return null
            if (shownSlot != null && expectedSlot != null) return shownSlot == expectedSlot
            return shownCardID == expectedCardID
        }

    /** How late the shown word was, when it was late. */
    val lag: Duration?
        get() = if (onTime == false && expectedSlot != null) maxOf(Duration.ZERO, Duration.between(expectedSlot, at)) else null
}

/** Records what Android does with the lock screen, widgets and notification. */
object WidgetLog {
    internal const val MAX_ROWS = 3000

    private fun insert(e: WidgetLogEntry, db: SqlDb) {
        db.execute(
            """INSERT INTO widget_log (at, kind, source, detail, shown_card_id, shown_slot, expected_card_id, expected_slot, reload_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            listOf(e.at, e.kind.raw, e.source, e.detail, e.shownCardID, e.shownSlot, e.expectedCardID, e.expectedSlot, e.reloadAt),
        )
        db.execute("DELETE FROM widget_log WHERE id NOT IN (SELECT id FROM widget_log ORDER BY at DESC LIMIT ?)", listOf(MAX_ROWS))
    }

    /** A surface drew [cardID] of [slot]; [nextAt] is when it asked to run again. */
    fun recordUpdate(source: String, cardID: String?, slot: Instant?, nextAt: Instant?, db: SqlDb, clock: AppClock, detail: String = "") {
        val current = WidgetQueue.current(db, clock)
        insert(
            WidgetLogEntry(
                at = clock.now, kind = WidgetLogEntry.Kind.TIMELINE, source = source, detail = detail,
                shownCardID = cardID, shownSlot = slot, expectedCardID = current?.cardID, expectedSlot = current?.slotStart, reloadAt = nextAt,
            ),
            db,
        )
    }

    fun recordAppReload(reason: String, db: SqlDb, clock: AppClock) =
        insert(WidgetLogEntry(at = clock.now, kind = WidgetLogEntry.Kind.APP_RELOAD, source = "app", detail = reason), db)

    fun recordTap(source: String, cardID: String, slot: Instant?, db: SqlDb, clock: AppClock, kind: WidgetLogEntry.Kind = WidgetLogEntry.Kind.TAP, detail: String = "") {
        val current = WidgetQueue.current(db, clock)
        insert(
            WidgetLogEntry(
                at = clock.now, kind = kind, source = source, detail = detail,
                shownCardID = cardID, shownSlot = slot, expectedCardID = current?.cardID, expectedSlot = current?.slotStart,
            ),
            db,
        )
    }

    fun recent(db: SqlDb, limit: Int = 500): List<WidgetLogEntry> =
        db.query("SELECT * FROM widget_log ORDER BY at DESC LIMIT ?", listOf(limit)) { row ->
            WidgetLogEntry(
                id = row.long("id"), at = row.instant("at")!!, kind = WidgetLogEntry.Kind.fromRaw(row.string("kind")),
                source = row.string("source") ?: "", detail = row.string("detail") ?: "",
                shownCardID = row.string("shown_card_id"), shownSlot = row.instant("shown_slot"),
                expectedCardID = row.string("expected_card_id"), expectedSlot = row.instant("expected_slot"),
                reloadAt = row.instant("reload_at"),
            )
        }

    fun clear(db: SqlDb) = db.execute("DELETE FROM widget_log")
}
