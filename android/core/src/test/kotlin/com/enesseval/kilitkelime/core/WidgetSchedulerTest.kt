package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.startOfDay
import com.enesseval.kilitkelime.core.learning.SchedulerCandidate
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.learning.WidgetScheduler
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.RotationInterval
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.time.Instant
import java.time.ZoneId

class WidgetSchedulerTest {
    private val now = Instant.ofEpochSecond(1_800_000_000)
    private val istanbul = ZoneId.of("Europe/Istanbul")
    private fun date(s: String) = Instant.parse(s)
    private val day = Duration.ofDays(1)

    @Test fun weights() {
        assertEquals(3.0, WidgetScheduler.weight(SchedulerCandidate("a", LearningState.STRUGGLING), now), 0.0)
        assertEquals(1.0, WidgetScheduler.weight(SchedulerCandidate("a", LearningState.NEW), now), 0.0)
        assertEquals(0.2, WidgetScheduler.weight(SchedulerCandidate("a", LearningState.LEARNED, now.minus(day.multipliedBy(15))), now), 0.0)
        assertEquals(0.0, WidgetScheduler.weight(SchedulerCandidate("a", LearningState.LEARNED, now.minus(day.multipliedBy(13))), now), 0.0)
        assertEquals(0.2, WidgetScheduler.weight(SchedulerCandidate("a", LearningState.LEARNED), now), 0.0)
    }

    @Test fun neverRepeatsWithinTwentySlots() {
        val rng = SeededGenerator(1u)
        val pool = (0 until 25).map { SchedulerCandidate("c$it", if (it < 5) LearningState.STRUGGLING else LearningState.NEW) }
        val history = mutableListOf<String>()
        repeat(2000) {
            val id = WidgetScheduler.pick(pool, history.reversed(), now, rng)!!
            assertFalse(history.takeLast(20).contains(id))
            history += id
        }
    }

    @Test fun strugglingIsPickedAboutThreeTimesAsOften() {
        val rng = SeededGenerator(42u)
        val pool = listOf(SchedulerCandidate("s", LearningState.STRUGGLING), SchedulerCandidate("n", LearningState.NEW))
        val counts = HashMap<String, Int>()
        repeat(20_000) { counts.merge(WidgetScheduler.pick(pool, emptyList(), now, rng)!!, 1, Int::plus) }
        val ratio = counts.getValue("s").toDouble() / counts.getValue("n")
        assertTrue("ratio $ratio", ratio in 2.8..3.2)
    }

    @Test fun recentlyShownLearnedCardsAreSkipped() {
        val rng = SeededGenerator(3u)
        val pool = listOf(
            SchedulerCandidate("fresh", LearningState.LEARNED, now.minusSeconds(3600)),
            SchedulerCandidate("old", LearningState.LEARNED, now.minus(day.multipliedBy(30))),
        )
        repeat(200) { assertEquals("old", WidgetScheduler.pick(pool, emptyList(), now, rng)) }
    }

    @Test fun tinyPoolReusesTheOldestRecentCard() {
        val pool = listOf("a", "b", "c").map { SchedulerCandidate(it, LearningState.NEW) }
        assertEquals("b", WidgetScheduler.pick(pool, listOf("a", "c", "b"), now, SeededGenerator(4u)))
    }

    @Test fun nothingWeightedReturnsNull() {
        val rng = SeededGenerator(5u)
        assertNull(WidgetScheduler.pick(listOf(SchedulerCandidate("a", LearningState.LEARNED, now)), emptyList(), now, rng))
        assertNull(WidgetScheduler.pick(emptyList(), emptyList(), now, rng))
    }

    @Test fun slotsAlignToLocalDayStart() {
        val at = date("2026-10-13T07:20:00Z")
        assertEquals(date("2026-10-13T06:00:00Z"), WidgetScheduler.slotStart(at, RotationInterval.THREE_HOURS, istanbul))
        assertEquals(date("2026-10-13T07:00:00Z"), WidgetScheduler.slotStart(at, RotationInterval.THIRTY_MINUTES, istanbul))
        assertEquals(date("2026-10-12T21:00:00Z"), WidgetScheduler.slotStart(at, RotationInterval.DAILY, istanbul))
    }

    @Test fun slotsCoverTheNext24Hours() {
        val at = date("2026-10-13T07:20:00Z")
        val threeHourly = WidgetScheduler.slots(at, RotationInterval.THREE_HOURS, istanbul)
        assertEquals(9, threeHourly.size)
        assertEquals(date("2026-10-13T06:00:00Z"), threeHourly.first())
        assertEquals(49, WidgetScheduler.slots(at, RotationInterval.THIRTY_MINUTES, istanbul).size)
        assertEquals(2, WidgetScheduler.slots(at, RotationInterval.DAILY, istanbul).size)
        assertTrue(threeHourly.zipWithNext().all { (a, b) -> Duration.between(a, b) == Duration.ofHours(3) })
    }

    @Test fun slotsRestartAtMidnightOnDSTDays() {
        val ny = ZoneId.of("America/New_York")
        val at = date("2026-03-08T15:00:00Z")
        val slots = WidgetScheduler.slots(at, RotationInterval.THREE_HOURS, ny)
        val nextMidnight = startOfDay(date("2026-03-09T12:00:00Z"), ny)
        assertTrue(slots.contains(nextMidnight))
        assertEquals(slots.sorted(), slots)
        assertEquals(slots.size, slots.toSet().size)
        assertEquals(listOf(startOfDay(at, ny), nextMidnight), WidgetScheduler.slots(at, RotationInterval.DAILY, ny))
    }

    @Test fun nextSlotIsTheNextBoundary() {
        val at = date("2026-10-13T07:20:00Z")
        assertEquals(date("2026-10-13T09:00:00Z"), WidgetScheduler.nextSlot(at, RotationInterval.THREE_HOURS, istanbul))
        assertEquals(date("2026-10-13T07:30:00Z"), WidgetScheduler.nextSlot(at, RotationInterval.THIRTY_MINUTES, istanbul))
    }

    @Test fun deckEntitlement() {
        assertEquals(listOf(DeckID.B1, DeckID.YDS), DeckID.entitled(listOf(DeckID.B1, DeckID.YDS)))
        assertEquals(listOf(DeckID.A2, DeckID.B1), DeckID.entitled(emptyList()))
    }
}
