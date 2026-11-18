package com.enesseval.kilitkelime.core.review

import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * When the system rating window may be asked for (docs/SYNC.md, 2026-11-18): only at the end of a good
 * moment, from the third studied day on, never when a paywall or the trial summary was up this session,
 * at least 120 days apart, at most 3 times, and not again once the learner used the "Uygulamayı değerlendir" row.
 */
object ReviewPrompt {
    const val MIN_STUDIED_DAYS = 3
    const val MIN_PERCENT = 80
    const val MIN_GAP_DAYS = 120
    const val MAX_PROMPTS = 3

    data class State(val count: Int = 0, val last: LocalDate? = null, val rowTapped: Boolean = false)

    fun state(db: SqlDb): State = State(
        count = Settings.int(db, SettingKey.REVIEW_PROMPT_COUNT) ?: 0,
        last = Settings.string(db, SettingKey.REVIEW_PROMPT_LAST)?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
        rowTapped = Settings.bool(db, SettingKey.REVIEW_ROW_TAPPED),
    )

    /** Days the learner studied (the streak history): not the streak itself. */
    fun studiedDays(db: SqlDb): Int = db.int("SELECT COUNT(*) FROM streak_day")

    /** [total] answers of a round or game, [correct] of them right; a puzzle that was finished counts as 1 of 1. */
    fun shouldAsk(studiedDays: Int, correct: Int, total: Int, paywallThisSession: Boolean, today: LocalDate, state: State): Boolean {
        if (total <= 0 || correct * 100 < MIN_PERCENT * total) return false
        if (studiedDays < MIN_STUDIED_DAYS) return false
        if (paywallThisSession) return false
        if (state.rowTapped) return false
        if (state.count >= MAX_PROMPTS) return false
        val last = state.last
        if (last != null && ChronoUnit.DAYS.between(last, today) < MIN_GAP_DAYS) return false
        return true
    }

    /** Checks the rule against the database and, when it passes, counts the prompt. True when it is to be shown. */
    fun take(db: SqlDb, correct: Int, total: Int, paywallThisSession: Boolean, today: LocalDate): Boolean {
        val state = state(db)
        if (!shouldAsk(studiedDays(db), correct, total, paywallThisSession, today, state)) return false
        Settings.setInt(db, SettingKey.REVIEW_PROMPT_COUNT, state.count + 1)
        Settings.set(db, SettingKey.REVIEW_PROMPT_LAST, today.toString())
        return true
    }

    /** The "Uygulamayı değerlendir" row was used: no automatic request again. */
    fun markRowTapped(db: SqlDb) = Settings.setBool(db, SettingKey.REVIEW_ROW_TAPPED, true)
}
