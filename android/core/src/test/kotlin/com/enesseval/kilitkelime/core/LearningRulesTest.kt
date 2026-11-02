package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningRules
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SchedulerCandidate
import com.enesseval.kilitkelime.core.learning.SpacedReview
import com.enesseval.kilitkelime.core.learning.WidgetScheduler
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.ReviewSource
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

class LearningRulesTest {
    private val day1 = LocalDate.of(2026, 10, 13)
    private val day2 = day1.addingDays(1)
    private val day3 = day1.addingDays(2)

    private fun apply(events: List<Pair<LearningEvent, LocalDate>>, start: CardState = CardState("x")) =
        events.fold(start) { s, (e, d) -> LearningRules.apply(e, s, d) }

    private val right = LearningEvent.Answered(true)
    private val wrong = LearningEvent.Answered(false)

    @Test fun wrongAnswerMakesStruggling() {
        for (from in LearningState.entries) {
            val s = apply(listOf(wrong to day1), CardState("x", from, 1))
            assertEquals(LearningState.STRUGGLING, s.state)
            assertEquals(0, s.correctStreak)
            assertEquals(day1, s.lastAnsweredOn)
        }
    }

    @Test fun hintMakesStrugglingWithoutCountingAsAnswer() {
        val s = apply(listOf(LearningEvent.HintUsed to day1), CardState("x", LearningState.LEARNED, 3, lastAnsweredOn = day1.addingDays(-5)))
        assertEquals(LearningState.STRUGGLING, s.state)
        assertEquals(0, s.correctStreak)
        assertEquals(day1.addingDays(-5), s.lastAnsweredOn)
    }

    @Test fun correctOnNewIsLearned() = assertEquals(LearningState.LEARNED, apply(listOf(right to day1)).state)

    @Test fun correctOnLearnedStaysLearned() =
        assertEquals(LearningState.LEARNED, apply(listOf(right to day1), CardState("x", LearningState.LEARNED)).state)

    @Test fun learnedWordsComeBackAtGrowingIntervals() {
        var s = apply(listOf(right to day1))
        assertEquals(day1.addingDays(3), SpacedReview.dueDate(s))
        assertFalse(SpacedReview.isDue(s, day1.addingDays(2)))
        assertTrue(SpacedReview.isDue(s, day1.addingDays(3)))
        s = apply(listOf(right to day1.addingDays(3), right to day1.addingDays(3)), s)
        assertEquals(2, s.correctStreak)
        assertEquals(day1.addingDays(10), SpacedReview.dueDate(s))
        assertEquals(listOf(3, 7, 21, 60, 120, 120, 120), (1..7).map { SpacedReview.interval(it) })
        s = apply(listOf(wrong to day1.addingDays(10)), s)
        assertTrue(s.state == LearningState.STRUGGLING && SpacedReview.dueDate(s) == null)
        assertEquals(day1.addingDays(3), SpacedReview.dueDate(apply(listOf(LearningEvent.MarkedKnown to day1))))
    }

    @Test fun dueWordsWeighMoreThanOtherLearnedWords() {
        val now = Instant.now()
        assertEquals(2.0, WidgetScheduler.weight(SchedulerCandidate("a", LearningState.LEARNED, now, due = true), now), 0.0)
        assertEquals(0.0, WidgetScheduler.weight(SchedulerCandidate("b", LearningState.LEARNED, now), now), 0.0)
    }

    @Test fun twoCorrectSameDayIsNotEnough() {
        val s = apply(listOf(wrong to day1, right to day1, right to day1))
        assertEquals(LearningState.STRUGGLING, s.state)
        assertEquals(1, s.correctStreak)
    }

    @Test fun twoCorrectOnDifferentDaysIsLearned() =
        assertEquals(LearningState.LEARNED, apply(listOf(wrong to day1, right to day1, right to day2)).state)

    @Test fun wrongAnswerResetsTheStreak() {
        val s = apply(listOf(LearningEvent.MarkedStruggling to day1, right to day1, wrong to day2, right to day3))
        assertEquals(LearningState.STRUGGLING, s.state)
        assertEquals(1, s.correctStreak)
    }

    @Test fun buttonsSetStateDirectly() {
        assertEquals(LearningState.LEARNED, apply(listOf(LearningEvent.MarkedKnown to day1)).state)
        val s = apply(listOf(LearningEvent.MarkedStruggling to day1), CardState("x", LearningState.LEARNED, 2))
        assertTrue(s.state == LearningState.STRUGGLING && s.correctStreak == 0)
    }

    @Test fun favoriteAndShownCountsSurviveEvents() {
        val s = apply(listOf(wrong to day1, LearningEvent.MarkedKnown to day2), CardState("x", timesShown = 4, favorite = true))
        assertTrue(s.favorite && s.timesShown == 4)
    }

    @Test fun storeUsesLocalDaysAcrossMidnight() {
        val istanbul = ZoneId.of("Europe/Istanbul")
        val late = AppClock.fixed(Instant.parse("2026-10-13T20:50:00Z"), istanbul)
        val early = AppClock.fixed(Instant.parse("2026-10-13T21:10:00Z"), istanbul)
        val db = TestSupport.database()
        LearningStore.record(LearningEvent.MarkedStruggling, "x", ReviewSource.WORD_DETAIL, late, db)
        LearningStore.record(right, "x", ReviewSource.QUICK_REVIEW, late, db)
        val state = LearningStore.record(right, "x", ReviewSource.QUICK_REVIEW, early, db)
        assertEquals(LearningState.LEARNED, state.state)
        assertEquals(listOf("2026-10-13", "2026-10-14"), db.strings("SELECT answered_on FROM review_log ORDER BY id"))
        assertEquals(listOf("2026-10-13", "2026-10-14"), db.strings("SELECT day FROM streak_day ORDER BY day"))
    }

    @Test fun storeLogsAnswersOnly() {
        val db = TestSupport.database()
        val clock = AppClock.fixed(Instant.ofEpochSecond(1_800_000_000), ZoneOffset.UTC)
        LearningStore.record(LearningEvent.HintUsed, "x", ReviewSource.PUZZLE, clock, db)
        LearningStore.record(LearningEvent.MarkedKnown, "x", ReviewSource.WIDGET, clock, db)
        LearningStore.record(wrong, "x", ReviewSource.WIDGET, clock, db, sessionID = "s1")
        LearningStore.setFavorite(true, "x", db)
        assertEquals(1, db.int("SELECT COUNT(*) FROM review_log"))
        assertEquals(listOf("s1"), db.strings("SELECT session_id FROM review_log"))
        val s = LearningStore.state("x", db)
        assertTrue(s.state == LearningState.STRUGGLING && s.favorite)
        assertNull(CardState.fetch(db, "missing"))
    }
}
