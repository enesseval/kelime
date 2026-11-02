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
     * (weekly stats) and mark the day studied (`streak_day`); hints and the buttons do not.
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
            markStudied(today, db)
        }
        return next
    }

    /** Counts [day] for the streak. */
    fun markStudied(day: LocalDate, db: SqlDb) {
        db.execute("INSERT OR IGNORE INTO streak_day (day) VALUES (?)", listOf(day))
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
    private val keptSettings = listOf(SettingKey.CONTENT_VERSION, SettingKey.CONTENT_CHECKED_AT, SettingKey.IS_PRO)

    fun reset(db: SqlDb) = db.transaction {
        for (table in listOf("card_state", "review_log", "puzzle_progress", "widget_queue", "streak_day", "game_result")) {
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
