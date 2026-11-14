package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.ExamCountdown
import com.enesseval.kilitkelime.core.model.ExamCountdownLine
import com.enesseval.kilitkelime.core.model.ExamPlan
import com.enesseval.kilitkelime.core.model.ExamPlanStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Sınav geri sayımı (docs/V1_2_PLAN.md §5). */
class ExamCountdownLineTest {
    private fun plan(exam: DeckID = DeckID.YDS, days: Int = 23, remaining: Int = 300, target: Int = 12, done: Int = 0) =
        ExamPlanStatus(exam, days, remaining, target, done, listOnWidget = true)

    @Test fun theLineReadsLikeThePlan() {
        assertEquals("YDS'ye 23 gün · bugün 12 kelime", ExamCountdownLine.text(true, plan()))
        assertEquals("YÖKDİL'e 5 gün · bugün 20 kelime", ExamCountdownLine.text(true, plan(DeckID.YOKDIL, 5, target = 20)))
        assertEquals("IELTS'e 1 gün · bugün 12 kelime", ExamCountdownLine.text(true, plan(DeckID.IELTS, 1)))
    }

    @Test fun doneForTodayAndEverythingLearned() {
        assertEquals("YDS'ye 23 gün · bugünkü hedef tamam", ExamCountdownLine.text(true, plan(done = 12)))
        assertEquals("YDS'ye 23 gün · hepsini öğrendin", ExamCountdownLine.text(true, plan(remaining = 0, target = 0)))
    }

    @Test fun examDayAndAfter() {
        assertEquals("YDS bugün · bugün 12 kelime", ExamCountdownLine.text(true, plan(days = 0)))
        // After the exam day the exam plan has no status (no date ahead): no line, the notification closes.
        assertNull(ExamCountdownLine.text(true, null))
        assertFalse(ExamCountdownLine.available(true, null))
    }

    @Test fun onlyForProAndTrial() {
        assertNull(ExamCountdownLine.text(false, plan()))
        assertTrue(ExamCountdownLine.available(true, plan()))
        assertFalse(ExamCountdownLine.available(false, plan()))
    }

    @Test fun theSwitchTurnsOffWhenTheDateIsGone() {
        assertTrue(ExamCountdownLine.stayEnabled(true, plan()))
        assertFalse(ExamCountdownLine.stayEnabled(true, null))
        assertFalse(ExamCountdownLine.stayEnabled(false, plan()))
        // Date deleted, then a new one entered: the plan is back, but the switch stayed off.
        val db = TestSupport.bundled()
        val clock = AppClock.fixed(Instant.parse("2026-11-14T10:00:00Z"), ZoneId.of("UTC"))
        ExamCountdown.set(DeckID.YDS, LocalDate.of(2026, 12, 7), db)
        var enabled = ExamCountdownLine.stayEnabled(true, ExamPlan.status(db, clock))
        assertTrue(enabled)
        ExamCountdown.clear(db)
        enabled = ExamCountdownLine.stayEnabled(enabled, ExamPlan.status(db, clock))
        assertFalse(enabled)
        ExamCountdown.set(DeckID.YDS, LocalDate.of(2027, 1, 20), db)
        assertFalse(ExamCountdownLine.stayEnabled(enabled, ExamPlan.status(db, clock)))
    }

    @Test fun noDateMeansNoCountdown() {
        val db = TestSupport.bundled()
        val clock = AppClock.fixed(Instant.parse("2026-11-14T10:00:00Z"), ZoneId.of("UTC"))
        assertNull(ExamPlan.status(db, clock))
        assertNull(ExamCountdownLine.text(true, ExamPlan.status(db, clock)))
    }

    @Test fun theStatusClosesAfterTheExamDay() {
        val db = TestSupport.bundled()
        ExamCountdown.set(DeckID.YDS, LocalDate.of(2026, 12, 7), db)
        fun at(day: String) = AppClock.fixed(Instant.parse("${day}T10:00:00Z"), ZoneId.of("UTC"))
        val before = ExamPlan.status(db, at("2026-11-14"))
        assertEquals(23, before!!.daysLeft)
        assertTrue(ExamCountdownLine.text(true, before)!!.startsWith("YDS'ye 23 gün"))
        assertEquals(0, ExamPlan.status(db, at("2026-12-07"))!!.daysLeft)
        // The day after: no status, so no line.
        assertNull(ExamPlan.status(db, at("2026-12-08")))
        assertNull(ExamCountdownLine.text(true, ExamPlan.status(db, at("2026-12-08"))))
    }
}
