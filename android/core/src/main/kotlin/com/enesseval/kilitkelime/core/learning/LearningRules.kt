package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.dates.daysSince
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.LearningState
import java.time.LocalDate

/** Something the user did with a card. */
sealed interface LearningEvent {
    /** A Quick Review, crossword, game or widget quiz answer. */
    data class Answered(val correct: Boolean) : LearningEvent
    /** Any crossword hint, or "Göster" in a game. */
    data object HintUsed : LearningEvent
    /** "Biliyorum". */
    data object MarkedKnown : LearningEvent
    /** "Zorlanıyorum". */
    data object MarkedStruggling : LearningEvent
}

/**
 * The learning-state rules, as pure functions (port of `LearningRules.swift`).
 *
 * - Wrong answer or any hint → struggling, streak resets to 0.
 * - Correct answer on a new word → learned.
 * - Correct answer on a struggling word increments the streak, at most once per local day;
 *   two correct answers on different local days → learned.
 * - "Biliyorum" → learned. "Zorlanıyorum" → struggling.
 */
object LearningRules {
    const val STREAK_TO_LEARN = 2

    fun apply(event: LearningEvent, current: CardState, day: LocalDate): CardState {
        var next = current
        when (event) {
            is LearningEvent.Answered -> if (!event.correct) {
                next = next.copy(state = LearningState.STRUGGLING, correctStreak = 0)
            } else {
                when (current.state) {
                    LearningState.NEW -> next = next.copy(state = LearningState.LEARNED, correctStreak = 1)
                    LearningState.STRUGGLING -> {
                        val alreadyCountedToday = current.correctStreak > 0 && current.lastAnsweredOn == day
                        var streak = current.correctStreak
                        if (!alreadyCountedToday) streak += 1
                        next = next.copy(
                            correctStreak = streak,
                            state = if (streak >= STREAK_TO_LEARN) LearningState.LEARNED else current.state,
                        )
                    }
                    LearningState.LEARNED -> if (current.lastAnsweredOn != day) {
                        next = next.copy(correctStreak = current.correctStreak + 1)
                    }
                }
            }
            LearningEvent.HintUsed, LearningEvent.MarkedStruggling ->
                next = next.copy(state = LearningState.STRUGGLING, correctStreak = 0)
            LearningEvent.MarkedKnown ->
                next = next.copy(state = LearningState.LEARNED, correctStreak = maxOf(current.correctStreak, 1))
        }
        if (event != LearningEvent.HintUsed) next = next.copy(lastAnsweredOn = day)
        return next
    }
}

/**
 * When learned words come back: after about 3, 7, 21, 60 and then every 120 days, counted from
 * the last answer.
 */
object SpacedReview {
    val intervals = listOf(3, 7, 21, 60, 120)

    fun interval(streak: Int): Int = intervals[minOf(maxOf(streak, 1), intervals.size) - 1]

    fun dueDate(state: CardState): LocalDate? {
        if (state.state != LearningState.LEARNED) return null
        val last = state.lastAnsweredOn ?: return null
        return last.addingDays(interval(state.correctStreak))
    }

    fun isDue(state: CardState, day: LocalDate): Boolean {
        val due = dueDate(state) ?: return false
        return due.daysSince(day) <= 0
    }
}
