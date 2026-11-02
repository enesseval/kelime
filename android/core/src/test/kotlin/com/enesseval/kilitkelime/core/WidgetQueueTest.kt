package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.RotationInterval
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.model.WidgetQueueEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class WidgetQueueTest {
    private val istanbul = ZoneId.of("Europe/Istanbul")
    private val start = Instant.parse("2026-10-13T07:20:00Z")
    private fun clock(offset: Long = 0) = AppClock.fixed(start.plusSeconds(offset), istanbul)
    private fun refill(db: JdbcSqlDb, clock: AppClock, seed: ULong = 7u) = WidgetQueue.refill(db, clock, SeededGenerator(seed))

    @Test fun fillsTheNextThreeDaysFromFreeDecks() {
        val db = TestSupport.bundled()
        val entries = refill(db, clock())
        assertEquals(25, entries.size)
        for (entry in entries) {
            val card = CardQueries.card(entry.cardID, db)!!
            assertTrue(card.level in listOf(CEFRLevel.A2, CEFRLevel.B1))
            assertEquals(2, entry.quizOptions.size)
            assertTrue(card.word in entry.quizOptions)
            assertEquals(2, entry.quizOptions.toSet().size)
        }
        assertEquals(entries.size, entries.map { it.cardID }.toSet().size)
    }

    @Test fun refillIsIdempotentAndKeepsQuizAnswers() {
        val db = TestSupport.bundled()
        val first = refill(db, clock())
        WidgetQueue.recordQuizAnswer(first[0].quizOptions[0], first[0].slotStart, db)
        val second = refill(db, clock(600), 99u)
        assertEquals(first.map { it.cardID }, second.map { it.cardID })
        assertEquals(first[0].quizOptions[0], second[0].quizAnswer)
    }

    @Test fun movingForwardDropsOldSlotsAndAddsNewOnes() {
        val db = TestSupport.bundled()
        val first = refill(db, clock())
        val later = refill(db, clock(4 * 3600))
        assertEquals(25, later.size)
        assertEquals(first[1].slotStart, later.first().slotStart)
        assertEquals(first.drop(1).map { it.cardID }, later.take(first.size - 1).map { it.cardID })
        assertEquals(26, db.int("SELECT COUNT(*) FROM widget_queue"))
    }

    @Test fun neverRepeatsWithinTwentySlotsAcrossRefills() {
        val db = TestSupport.bundled(Preferences(rotationInterval = RotationInterval.THIRTY_MINUTES, isPro = true))
        val shown = sortedMapOf<Instant, String>()
        for (hour in 0 until 24 * 4 step 5) {
            for (e in refill(db, clock(hour * 3600L), hour.toULong())) shown[e.slotStart] = e.cardID
        }
        val ordered = shown.values.toList()
        assertTrue(ordered.size > 150)
        for (i in ordered.indices) assertFalse(ordered.subList(maxOf(0, i - 20), i).contains(ordered[i]))
    }

    @Test fun rotationSettingChangesTheGrid() {
        val db = TestSupport.bundled(Preferences(rotationInterval = RotationInterval.THIRTY_MINUTES, isPro = false))
        assertEquals(25, refill(db, clock()).size)
        Settings.setBool(db, SettingKey.IS_PRO, true)
        assertEquals(145, refill(db, clock()).size)
        Settings.setInt(db, SettingKey.ROTATION_INTERVAL, RotationInterval.DAILY.minutes)
        val daily = refill(db, clock())
        assertEquals(4, daily.size)
        assertEquals(4, db.int("SELECT COUNT(*) FROM widget_queue WHERE slot_start >= ?", listOf(daily[0].slotStart)))
    }

    @Test fun examDecksAreFree() {
        val db = TestSupport.bundled(Preferences(enabledDecks = listOf(DeckID.YDS), isPro = false))
        for (e in refill(db, clock())) {
            assertEquals(1, db.int("SELECT COUNT(*) FROM card_deck WHERE card_id = ? AND deck = 'yds'", listOf(e.cardID)))
        }
    }

    @Test fun startedSlotsAreCountedOnce() {
        val db = TestSupport.bundled()
        val entries = refill(db, clock())
        refill(db, clock(60))
        refill(db, clock(3 * 3600))
        val first = LearningStore.state(entries[0].cardID, db)
        assertEquals(1, first.timesShown)
        assertEquals(entries[0].slotStart, first.lastShownAt)
        assertEquals(1, LearningStore.state(entries[1].cardID, db).timesShown)
        assertEquals(0, LearningStore.state(entries[2].cardID, db).timesShown)
    }

    @Test fun strugglingCardsShowUpMoreOften() {
        val db = TestSupport.bundled(Preferences(rotationInterval = RotationInterval.THIRTY_MINUTES, isPro = true))
        val ids = db.strings("SELECT card_id FROM unit_card WHERE unit_id IN ('a2-core', 'b1-core') ORDER BY card_id LIMIT 10")
        for (id in ids) CardState(id, LearningState.STRUGGLING).save(db)
        var hits = 0
        var total = 0
        for (day in 0 until 10) {
            for (e in refill(db, clock(day * 86_400L), day.toULong())) {
                total++
                if (e.cardID in ids) hits++
            }
        }
        assertTrue(hits.toDouble() / total > 0.15)
    }

    @Test fun emptyContentGivesNoEntries() {
        assertTrue(refill(TestSupport.database(), clock()).isEmpty())
    }

    @Test fun distractorsPreferSameLevelAndPartOfSpeech() {
        val db = TestSupport.bundled()
        val rng = SeededGenerator(11u)
        val card = CardQueries.card("b2-reluctant", db)!!
        val words = CardQueries.distractors(card, 3, db, rng)
        assertEquals(3, words.size)
        assertFalse("reluctant" in words)
        for (word in words) {
            val other = db.query("SELECT * FROM card WHERE word = ? LIMIT 1", listOf(word), Card::from).first()
            assertTrue(other.level == CEFRLevel.B2 && other.pos == PartOfSpeech.ADJECTIVE)
        }
        val options = CardQueries.quizOptions(card, 4, db, rng)
        assertTrue(options.size == 4 && "reluctant" in options)
    }

    @Test fun distractorsNeverShareTheAnswersMeaning() {
        val db = TestSupport.bundled()
        val convince = CardQueries.card("b2-convince", db)!!
        val all = db.query("SELECT * FROM card", emptyList(), Card::from)
        for (seed in 0uL until 200uL) {
            val options = CardQueries.quizOptions(convince, 4, db, SeededGenerator(seed))
            assertFalse("persuade" in options)
            for (word in options.filter { it != convince.word }) {
                val other = all.first { it.word == word }
                assertTrue(Card.normalizedMeanings(other.tr).intersect(Card.normalizedMeanings(convince.tr)).isEmpty())
            }
        }
    }

    @Test fun clearFutureKeepsTheCurrentSlot() {
        val db = TestSupport.bundled()
        val entries = refill(db, clock())
        WidgetQueue.clearFuture(db, clock())
        assertEquals(entries[0].cardID, WidgetQueue.current(db, clock())?.cardID)
        assertEquals(1, db.int("SELECT COUNT(*) FROM widget_queue"))
    }

    @Test fun queueEntriesRoundTrip() {
        val db = TestSupport.database()
        WidgetQueueEntry(start, "x", listOf("a", "b")).insert(db)
        assertEquals(listOf("a", "b"), WidgetQueue.entry(start, db)?.quizOptions)
    }
}
