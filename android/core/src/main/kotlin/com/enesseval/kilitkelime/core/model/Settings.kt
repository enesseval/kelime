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
    /** 1.2: a store purchase (the entitlement). `IS_PRO` is purchase or running free trial. */
    PURCHASED("purchased"),
    /** 1.2: the free trial (docs/V1_2_PLAN.md §2): start and latest time seen, epoch ms; summary and end-signal flags. */
    TRIAL_START("trial_start"),
    TRIAL_SEEN("trial_seen"),
    TRIAL_SUMMARY_SHOWN("trial_summary_shown"),
    TRIAL_ENDED_SENT("trial_ended_sent"),
    /** 1.2: what the trial used, for the summary page. */
    TRIAL_ARCHIVE_DAYS("trial_archive_days"),
    TRIAL_PERSONAL("trial_personal"),
    /** 1.2: free archive puzzles opened this week: "monday|day,day". */
    ARCHIVE_QUOTA("archive_quota"),
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
