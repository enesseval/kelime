package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import java.time.LocalDate

/** Applies learning events to the database. Used by the app, the widgets and the games. */
object LearningStore {
    fun state(cardID: String, db: SqlDb): CardState = CardState.fetch(db, cardID) ?: CardState(cardID)

    /**
     * Records [event] for [cardID] and returns the new state. Answers also get a `review_log` row
     * (weekly stats); hints and the buttons do not. Answers do not count for the streak by
     * themselves (a widget answer must not): finishing a round does, see [markStudied].
     */
    fun record(
        event: LearningEvent,
        cardID: String,
        source: ReviewSource,
        clock: AppClock,
        db: SqlDb,
        sessionID: String? = null,
    ): CardState {
        val now = clock.now
        val today = clock.today
        val next = LearningRules.apply(event, state(cardID, db), today)
        next.save(db)
        if (event is LearningEvent.Answered) {
            db.execute(
                "INSERT INTO review_log (card_id, answered_at, answered_on, correct, source, session_id) VALUES (?, ?, ?, ?, ?, ?)",
                listOf(cardID, now, today, event.correct, source, sessionID),
            )
        }
        return next
    }

    /**
     * Counts [day] for the streak (finished Quick Review, a solved word in the daily puzzle, a
     * finished game). Returns true when the day was not counted yet (`streak.day`).
     */
    fun markStudied(day: LocalDate, source: com.enesseval.kilitkelime.core.games.StreakSource, db: SqlDb): Boolean {
        val exists = db.query("SELECT 1 FROM streak_day WHERE day = ?", listOf(day)) { true }.isNotEmpty()
        if (exists) return false
        db.execute("INSERT INTO streak_day (day, source) VALUES (?, ?)", listOf(day, source.raw))
        return true
    }

    fun setFavorite(favorite: Boolean, cardID: String, db: SqlDb) {
        state(cardID, db).copy(favorite = favorite).save(db)
    }
}

/**
 * Starts the learner over: progress, reviews, puzzles, the queue and every onboarding choice.
 * Content, own lists, the purchase and the widget log stay.
 */
object ProgressReset {
    const val EPOCH = 1
    private val keptSettings = listOf(
        SettingKey.CONTENT_VERSION, SettingKey.CONTENT_CHECKED_AT, SettingKey.IS_PRO, SettingKey.PURCHASED,
        SettingKey.TRIAL_START, SettingKey.TRIAL_SEEN, SettingKey.TRIAL_SUMMARY_SHOWN, SettingKey.TRIAL_ENDED_SENT,
        SettingKey.TRIAL_ARCHIVE_DAYS, SettingKey.TRIAL_PERSONAL, SettingKey.ARCHIVE_QUOTA,
    )

    fun reset(db: SqlDb) = db.transaction {
        for (table in listOf("card_state", "review_log", "puzzle_progress", "widget_queue", "streak_day", "game_result", "widget_shown")) {
            db.execute("DELETE FROM $table")
        }
        val kept = keptSettings.map { it.key }
        db.execute("DELETE FROM settings WHERE key NOT IN (${kept.joinToString(",") { "?" }})", kept)
        Preferences.load(db).copy(level = com.enesseval.kilitkelime.core.model.CEFRLevel.A1,
            enabledDecks = listOf(com.enesseval.kilitkelime.core.model.DeckID.A1)).save(db)
        Settings.setInt(db, SettingKey.PROGRESS_EPOCH, EPOCH)
    }

    /** Resets once per epoch; true when it reset, so onboarding shows again. */
    fun resetIfNeeded(db: SqlDb): Boolean {
        if ((Settings.int(db, SettingKey.PROGRESS_EPOCH) ?: 0) >= EPOCH) return false
        reset(db)
        return true
    }
}
