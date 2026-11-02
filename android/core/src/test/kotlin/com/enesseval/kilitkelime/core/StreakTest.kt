package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.games.Streak
import com.enesseval.kilitkelime.core.games.StreakSource
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId

/** docs/V1_1_PLAN.md §1. */
class StreakTest {
    // Thursday 15 October 2026.
    private val today = LocalDate.of(2026, 10, 15)
    private fun days(vararg ago: Int) = ago.map { today.minusDays(it.toLong()) }.toSet()

    @Test fun countsDaysInARowIncludingToday() {
        val s = Streak.compute(days(0, 1, 2), today, 1)
        assertEquals(3, s.current)
        assertTrue(s.studiedToday)
        assertFalse(s.atRisk)
    }

    @Test fun anOpenTodayPutsTheStreakAtRiskWithoutEndingIt() {
        val s = Streak.compute(days(1, 2, 3), today, 1)
        assertEquals(3, s.current)
        assertTrue(s.atRisk)
        assertTrue(s.frozen.isEmpty())
    }

    @Test fun oneMissedDayIsSavedByTheWeeklyFreeze() {
        // Tue 13 missed, between Mon 12 and Wed 14.
        val s = Streak.compute(days(0, 1, 3, 4), today, 1)
        assertEquals(4, s.current)
        assertEquals(setOf(today.minusDays(2)), s.frozen)
        assertEquals(0, s.freezesLeftThisWeek)
    }

    @Test fun twoMissedDaysInARowEndTheStreak() {
        val s = Streak.compute(days(0, 3, 4), today, 1)
        assertEquals(1, s.current)
        assertTrue(s.frozen.isEmpty())
        assertEquals(2, s.longest)
    }

    @Test fun aSecondGapInTheSameWeekNeedsPro() {
        // Week of Monday 12 October: studied Mon, Wed, Fri; Tue and Thu missed.
        val studied = setOf(LocalDate.of(2026, 10, 12), LocalDate.of(2026, 10, 14), LocalDate.of(2026, 10, 16))
        val friday = LocalDate.of(2026, 10, 16)
        assertEquals(DayOfWeek.FRIDAY, friday.dayOfWeek)
        assertEquals(1, Streak.compute(studied, friday, Streak.freezesPerWeek(false)).current) // Thursday breaks it
        val pro = Streak.compute(studied, friday, Streak.freezesPerWeek(true))
        assertEquals(3, pro.current)
        assertEquals(setOf(LocalDate.of(2026, 10, 13), LocalDate.of(2026, 10, 15)), pro.frozen)
    }

    @Test fun freezesRenewEveryMonday() {
        // Gap on Sun 11 (week of 5 Oct) and on Tue 13 (week of 12 Oct): one freeze each.
        val studied = setOf(LocalDate.of(2026, 10, 10), LocalDate.of(2026, 10, 12), LocalDate.of(2026, 10, 14), today)
        assertEquals(4, Streak.compute(studied, today, 1).current)
    }

    @Test fun yesterdayMissedIsFrozenWhileTodayIsOpen() {
        val s = Streak.compute(days(2, 3), today, 1)
        assertEquals(2, s.current)
        assertTrue(s.atRisk)
        assertEquals(setOf(today.minusDays(1)), s.frozen)
    }

    @Test fun longestStreakIsKept() {
        val db = TestSupport.database()
        val clock = AppClock.fixed(today.atTime(12, 0).atZone(ZoneId.of("Europe/Istanbul")).toInstant(), ZoneId.of("Europe/Istanbul"))
        for (ago in 10..15) LearningStore.markStudied(today.minusDays(ago.toLong()), StreakSource.QUICK_REVIEW, db)
        LearningStore.markStudied(today, StreakSource.PUZZLE, db)
        val s = Streak.status(db, clock, false)
        assertEquals(1, s.current)
        assertEquals(6, s.longest)
        assertEquals(6, Settings.int(db, SettingKey.LONGEST_STREAK))
        db.execute("DELETE FROM streak_day")
        assertEquals(6, Streak.status(db, clock, false).longest)
    }

    @Test fun milestonesAndCalendar() {
        val seven = Streak.compute((0..6).map { today.minusDays(it.toLong()) }.toSet(), today, 1)
        assertEquals(7, Streak.milestone(seven))
        assertNull(Streak.milestone(Streak.compute(days(0, 1), today, 1)))
        val weeks = Streak.calendar(today)
        assertEquals(5, weeks.size)
        assertTrue(weeks.all { it.size == 7 && it.first().dayOfWeek == DayOfWeek.MONDAY })
        assertTrue(today in weeks.last())
    }
}
