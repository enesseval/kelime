package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.dates.dayIndex
import com.enesseval.kilitkelime.core.dates.daysSince
import com.enesseval.kilitkelime.core.dates.startInstant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class LocalDateTest {
    private val istanbul = ZoneId.of("Europe/Istanbul")
    private val newYork = ZoneId.of("America/New_York")
    private fun utc(s: String) = Instant.parse(s)

    @Test fun formatsAndParses() {
        val d = LocalDate.of(2026, 3, 7)
        assertEquals("2026-03-07", d.toString())
        assertEquals(d, LocalDates.parse("2026-03-07"))
    }

    @Test fun rejectsInvalidStrings() {
        for (raw in listOf("2026-02-30", "2026-1-01", "26-01-01", "2026-13-01", "2026-01-00", "", "abcd-ef-gh")) {
            assertNull(raw, LocalDates.parse(raw))
        }
    }

    @Test fun acceptsLeapDay() {
        assertNotNull(LocalDates.parse("2028-02-29"))
        assertNull(LocalDates.parse("2027-02-29"))
    }

    @Test fun usesLocalDayNotUTC() {
        val instant = utc("2026-10-13T21:30:00Z")
        assertEquals("2026-10-14", LocalDates.of(instant, istanbul).toString())
        assertEquals("2026-10-13", LocalDates.of(instant, newYork).toString())
    }

    @Test fun clockCrossesMidnight() {
        val before = AppClock.fixed(utc("2026-10-13T20:59:59Z"), istanbul)
        val after = AppClock.fixed(utc("2026-10-13T21:00:00Z"), istanbul)
        assertEquals("2026-10-13", before.today.toString())
        assertEquals("2026-10-14", after.today.toString())
        assertEquals(1, after.today.daysSince(before.today))
    }

    @Test fun handlesDSTSpringForward() {
        val day = LocalDate.of(2026, 3, 8)
        val start = day.startInstant(newYork)
        assertEquals(utc("2026-03-08T05:00:00Z"), start)
        assertEquals(Duration.ofHours(23), Duration.between(start, day.addingDays(1).startInstant(newYork)))
        assertEquals("2026-03-09", LocalDates.of(utc("2026-03-09T04:30:00Z"), newYork).toString())
    }

    @Test fun handlesDSTFallBack() {
        val day = LocalDate.of(2026, 11, 1)
        assertEquals(Duration.ofHours(25), Duration.between(day.startInstant(newYork), day.addingDays(1).startInstant(newYork)))
        assertEquals("2026-11-01", LocalDates.of(utc("2026-11-02T04:59:00Z"), newYork).toString())
    }

    @Test fun dayArithmetic() {
        val d = LocalDate.of(2026, 12, 31)
        assertEquals("2027-01-01", d.addingDays(1).toString())
        assertEquals("2025-12-31", d.addingDays(-365).toString())
        assertEquals("2028-02-29", LocalDate.of(2028, 2, 28).addingDays(1).toString())
        assertEquals(1, LocalDate.of(2027, 1, 1).daysSince(d))
        assertEquals(0, LocalDates.EPOCH.dayIndex)
        assertEquals(-1, LocalDate.of(2025, 12, 31).dayIndex)
        assertEquals(285, LocalDate.of(2026, 10, 13).dayIndex)
    }

    @Test fun comparesChronologically() {
        assertTrue(LocalDate.of(2026, 1, 31) < LocalDate.of(2026, 2, 1))
        assertTrue(LocalDate.of(2025, 12, 31) < LocalDate.of(2026, 1, 1))
    }

    @Test fun roundTripsThroughDatabase() {
        val db = TestSupport.database()
        val d = LocalDate.of(2026, 10, 13)
        assertEquals(d, db.query("SELECT ? AS d", listOf(d)) { it.localDate("d") }.first())
    }
}
