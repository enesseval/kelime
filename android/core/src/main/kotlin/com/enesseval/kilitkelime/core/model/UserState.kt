package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.db.RawValue
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.SqlRow
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import java.time.Instant
import java.time.LocalDate

/** Learning state of a card: Yeni / Zorlanılan / Öğrenildi. */
enum class LearningState(override val raw: String) : RawValue {
    NEW("new"), STRUGGLING("struggling"), LEARNED("learned");

    /** Turkish label. */
    val label: String
        get() = when (this) {
            NEW -> "Yeni"
            STRUGGLING -> "Zorlanılan"
            LEARNED -> "Öğrenildi"
        }

    companion object {
        fun fromRaw(raw: String?): LearningState? = entries.firstOrNull { it.raw == raw }
    }
}

/** Per-card progress. A missing row means the card is new and was never shown. */
data class CardState(
    val cardID: String,
    val state: LearningState = LearningState.NEW,
    val correctStreak: Int = 0,
    val lastShownAt: Instant? = null,
    val lastAnsweredOn: LocalDate? = null,
    val timesShown: Int = 0,
    val favorite: Boolean = false,
) {
    fun save(db: SqlDb) {
        db.execute(
            """INSERT OR REPLACE INTO card_state
               (card_id, state, correct_streak, last_shown_at, last_answered_on, times_shown, favorite)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            listOf(cardID, state, correctStreak, lastShownAt, lastAnsweredOn, timesShown, favorite),
        )
    }

    companion object {
        fun from(row: SqlRow) = CardState(
            cardID = row.requireString("card_id"),
            state = LearningState.fromRaw(row.string("state")) ?: LearningState.NEW,
            correctStreak = row.int("correct_streak") ?: 0,
            lastShownAt = row.instant("last_shown_at"),
            lastAnsweredOn = row.localDate("last_answered_on"),
            timesShown = row.int("times_shown") ?: 0,
            favorite = row.bool("favorite"),
        )

        fun fetch(db: SqlDb, cardID: String): CardState? =
            db.query("SELECT * FROM card_state WHERE card_id = ?", listOf(cardID), ::from).firstOrNull()
    }
}

/** One rotation slot of the widget timeline. */
data class WidgetQueueEntry(
    val slotStart: Instant,
    val cardID: String,
    /** English options for the quiz widget, the answer included. */
    val quizOptions: List<String>,
    /** The option the user tapped, kept until the next slot. */
    val quizAnswer: String? = null,
    /** True once this slot has been counted as shown in `card_state`. */
    val counted: Boolean = false,
) {
    fun insert(db: SqlDb) {
        db.execute(
            "INSERT INTO widget_queue (slot_start, card_id, quiz_options, quiz_answer, counted) VALUES (?, ?, ?, ?, ?)",
            listOf(slotStart, cardID, encodeOptions(quizOptions), quizAnswer, counted),
        )
    }

    companion object {
        private val listSerializer = ListSerializer(String.serializer())
        fun encodeOptions(options: List<String>): String = Json.encodeToString(listSerializer, options)

        fun from(row: SqlRow) = WidgetQueueEntry(
            slotStart = row.instant("slot_start")!!,
            cardID = row.requireString("card_id"),
            quizOptions = row.string("quiz_options")?.let { Json.decodeFromString(listSerializer, it) } ?: emptyList(),
            quizAnswer = row.string("quiz_answer"),
            counted = row.bool("counted"),
        )
    }
}

/** Where an answer came from. */
enum class ReviewSource(override val raw: String) : RawValue {
    QUICK_REVIEW("quickReview"), PUZZLE("puzzle"), WIDGET("widget"), WORD_DETAIL("wordDetail"),
    /** 1.1 games. */
    WORD_HUNT("wordHunt"), MATCH("match"),
    /** 1.2 games. */
    SENTENCE("sentence"), GAP_FILL("gapFill"),
}

/** Saved state of a daily or personal crossword (and kept course grids, `…-grid`). */
data class PuzzleProgress(
    val puzzleKey: String,
    val cells: String,
    val hintsUsed: Int = 0,
    val completedAt: Instant? = null,
    val seconds: Int = 0,
) {
    fun save(db: SqlDb) {
        db.execute(
            "INSERT OR REPLACE INTO puzzle_progress (puzzle_key, cells, hints_used, completed_at, seconds) VALUES (?, ?, ?, ?, ?)",
            listOf(puzzleKey, cells, hintsUsed, completedAt, seconds),
        )
    }

    companion object {
        fun fetch(db: SqlDb, key: String): PuzzleProgress? =
            db.query("SELECT * FROM puzzle_progress WHERE puzzle_key = ?", listOf(key)) { row ->
                PuzzleProgress(
                    puzzleKey = row.requireString("puzzle_key"),
                    cells = row.requireString("cells"),
                    hintsUsed = row.int("hints_used") ?: 0,
                    completedAt = row.instant("completed_at"),
                    seconds = row.int("seconds") ?: 0,
                )
            }.firstOrNull()
    }
}
