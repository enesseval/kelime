package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.stringOrNull
import java.time.LocalDate

/** Keys of the key-value `settings` table (same keys as iOS). */
enum class SettingKey(val key: String) {
    LEVEL("level"),
    EXAM("exam"),
    EXAM_DATE("exam_date"),
    ENABLED_DECKS("enabled_decks"),
    ROTATION_INTERVAL("rotation_interval"),
    DEFAULT_WIDGET_MODE("default_widget_mode"),
    THEME("theme"),
    WIDGET_CONTENT("widget_content"),
    /** When the quiz widget was last answered, seconds since 1970. */
    QUIZ_ANSWERED_AT("quiz_answered_at"),
    REMINDER_TIME("reminder_time"),
    IS_PRO("is_pro"),
    ONBOARDING_DONE("onboarding_done"),
    CONTENT_VERSION("content_version"),
    WIDGET_BANNER_DISMISSED("widget_banner_dismissed"),
    DAILY_PUZZLE_SUMMARY("daily_puzzle_summary"),
    SPEECH_RATE("speech_rate"),
    WIDGET_PROBE("widget_probe"),
    UNITS_STARTED("units_started"),
    CURRENT_UNIT("current_unit"),
    CONTENT_CHECKED_AT("content_checked_at"),
    PROGRESS_EPOCH("progress_epoch"),
    /** 1.1: the longest streak so far. */
    LONGEST_STREAK("longest_streak"),
    /** 1.1: best Eşleştir score. */
    MATCH_BEST("match_best"),
}

/** Typed access to the `settings` table. Values are stored as text. */
object Settings {
    fun string(db: SqlDb, key: SettingKey): String? =
        db.stringOrNull("SELECT value FROM settings WHERE key = ?", listOf(key.key))

    fun set(db: SqlDb, key: SettingKey, value: String?) {
        if (value != null) {
            db.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", listOf(key.key, value))
        } else {
            db.execute("DELETE FROM settings WHERE key = ?", listOf(key.key))
        }
    }

    fun int(db: SqlDb, key: SettingKey): Int? = string(db, key)?.toIntOrNull()
    fun setInt(db: SqlDb, key: SettingKey, value: Int?) = set(db, key, value?.toString())

    fun bool(db: SqlDb, key: SettingKey): Boolean = string(db, key) == "1"
    fun setBool(db: SqlDb, key: SettingKey, value: Boolean) = set(db, key, if (value) "1" else "0")

    fun date(db: SqlDb, key: SettingKey): LocalDate? = string(db, key)?.let(LocalDates::parse)
    fun setDate(db: SqlDb, key: SettingKey, value: LocalDate?) = set(db, key, value?.toString())
}
