package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.review.ReviewPrompt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** The automatic rating request (docs/SYNC.md, 2026-11-18). */
class ReviewPromptTest {
    private val today = LocalDate.of(2026, 11, 20)

    private fun ask(
        days: Int = 3, correct: Int = 8, total: Int = 10, paywall: Boolean = false,
        state: ReviewPrompt.State = ReviewPrompt.State(), on: LocalDate = today,
    ) = ReviewPrompt.shouldAsk(days, correct, total, paywall, on, state)

    @Test fun notBeforeTheThirdStudiedDay() {
        assertFalse(ask(days = 1))
        assertFalse(ask(days = 2))
        assertTrue(ask(days = 3))
        assertTrue(ask(days = 9))
    }

    @Test fun atLeastEightyPercentRight() {
        assertTrue(ask(correct = 8, total = 10))
        assertFalse(ask(correct = 79, total = 100))
        assertTrue(ask(correct = 80, total = 100))
        assertFalse(ask(correct = 0, total = 0))
        assertTrue(ask(correct = 1, total = 1)) // a finished puzzle
    }

    @Test fun notWhenAPaywallOrTheTrialSummaryWasUpThisSession() {
        assertFalse(ask(paywall = true))
    }

    @Test fun oneHundredTwentyDaysBetweenTwoRequests() {
        val last = today.minusDays(119)
        assertFalse(ask(state = ReviewPrompt.State(1, last)))
        assertTrue(ask(state = ReviewPrompt.State(1, today.minusDays(120))))
        assertTrue(ask(state = ReviewPrompt.State(1, today.minusDays(400))))
    }

    @Test fun atMostThreeRequests() {
        val long = today.minusDays(500)
        assertTrue(ask(state = ReviewPrompt.State(2, long)))
        assertFalse(ask(state = ReviewPrompt.State(3, long)))
    }

    @Test fun neverAgainAfterTheRowWasUsed() {
        assertFalse(ask(state = ReviewPrompt.State(0, null, rowTapped = true)))
    }

    @Test fun theDatabaseKeepsTheCountTheDateAndTheRow() {
        val db = TestSupport.database()
        assertEquals(ReviewPrompt.State(), ReviewPrompt.state(db))
        db.execute("INSERT INTO streak_day (day, source) VALUES ('2026-11-18', 'quickReview')")
        db.execute("INSERT INTO streak_day (day, source) VALUES ('2026-11-19', 'quickReview')")
        // Two studied days: no.
        assertFalse(ReviewPrompt.take(db, 9, 10, false, today))
        assertEquals(0, ReviewPrompt.state(db).count)
        db.execute("INSERT INTO streak_day (day, source) VALUES ('2026-11-20', 'quickReview')")
        assertEquals(3, ReviewPrompt.studiedDays(db))
        // The third day: yes, and it is counted.
        assertTrue(ReviewPrompt.take(db, 9, 10, false, today))
        assertEquals(ReviewPrompt.State(1, today), ReviewPrompt.state(db))
        // The next day it is too soon.
        assertFalse(ReviewPrompt.take(db, 10, 10, false, today.plusDays(1)))
        assertTrue(ReviewPrompt.take(db, 10, 10, false, today.plusDays(120)))
        assertEquals(2, ReviewPrompt.state(db).count)
        ReviewPrompt.markRowTapped(db)
        assertFalse(ReviewPrompt.take(db, 10, 10, false, today.plusDays(900)))
        assertTrue(ReviewPrompt.state(db).rowTapped)
    }
}
