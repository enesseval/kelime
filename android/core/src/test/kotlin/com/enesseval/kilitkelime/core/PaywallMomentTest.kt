package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.games.StreakSource
import com.enesseval.kilitkelime.core.model.PaywallMoment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The unprompted Pro offer (SYNC.md 2026-11-03). */
class PaywallMomentTest {
    private val day = 24L * 3600 * 1000
    private val now = 100 * day

    @Test fun needsThreeStudyDays() {
        assertFalse(PaywallMoment.shouldOffer(2, 0, 0, 0, now))
        assertTrue(PaywallMoment.shouldOffer(3, 0, 0, 0, now))
    }

    @Test fun atMostTwoOffersFourteenDaysApart() {
        assertFalse(PaywallMoment.shouldOffer(5, 1, now - 13 * day, 0, now))
        assertTrue(PaywallMoment.shouldOffer(5, 1, now - 14 * day, 0, now))
        assertFalse(PaywallMoment.shouldOffer(9, 2, now - 60 * day, 0, now))
    }

    @Test fun quietFortyEightHoursAfterAnyPaywall() {
        assertFalse(PaywallMoment.shouldOffer(5, 0, 0, now - 47 * 3600 * 1000L, now))
        assertTrue(PaywallMoment.shouldOffer(5, 0, 0, now - 48 * 3600 * 1000L, now))
    }

    @Test fun studyDaysCountsDistinctDays() {
        val db = TestSupport.database()
        assertEquals(0, PaywallMoment.studyDays(db))
        for (d in listOf("2026-10-01", "2026-10-02", "2026-10-04")) {
            db.execute("INSERT INTO streak_day (day, source) VALUES (?, ?)", listOf(d, StreakSource.QUICK_REVIEW.raw))
        }
        assertEquals(3, PaywallMoment.studyDays(db))
    }
}
