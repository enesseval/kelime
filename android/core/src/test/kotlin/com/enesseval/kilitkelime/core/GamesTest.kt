package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.games.GameResults
import com.enesseval.kilitkelime.core.games.GameWords
import com.enesseval.kilitkelime.core.games.MatchRound
import com.enesseval.kilitkelime.core.games.WordHunt
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.queries.StatsQueries
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class GamesTest {
    private val clock = AppClock.fixed(Instant.parse("2026-10-14T09:00:00Z"), ZoneId.of("Europe/Istanbul"))

    @Test fun gameWordsPreferStrugglingAndNeverShareAMeaning() {
        val db = TestSupport.bundled()
        CardState("b1-avoid", LearningState.STRUGGLING).save(db)
        val words = GameWords.pick(db, SeededGenerator(1u), 6)
        assertEquals(6, words.size)
        assertEquals("b1-avoid", words.first().id)
        val meanings = words.map { Card.normalizedMeanings(it.tr) }
        assertEquals(meanings.sumOf { it.size }, meanings.flatten().toSet().size)
    }

    @Test fun wordHuntHidesWordsThatCanBeFound() {
        val db = TestSupport.bundled()
        for (seed in 0uL until 50uL) {
            val rng = SeededGenerator(seed)
            val cards = GameWords.pick(db, rng, 20) { it.isSingleWord && it.word.length <= WordHunt.SIZE }
            val hunt = WordHunt.make(cards, rng)
            assertNotNull(hunt)
            hunt!!
            assertTrue(hunt.words.size in 3..WordHunt.WORDS)
            assertEquals(64, hunt.letters.size)
            for (w in hunt.words) {
                assertEquals(w.answer, w.cells.joinToString("") { (r, c) -> hunt.letter(r, c).toString() })
                assertEquals(w, hunt.match(w.cells.first(), w.cells.last()))
                assertEquals(w, hunt.match(w.cells.last(), w.cells.first()))
                assertTrue(w.cells.all { (r, c) -> r in 0 until 8 && c in 0 until 8 })
            }
            assertTrue(hunt.letters.all { it in 'A'..'Z' })
        }
    }

    @Test fun wordHuntNeedsEnoughWords() {
        assertNull(WordHunt.make(listOf(TestSupport.card("cat")), SeededGenerator(1u)))
    }

    @Test fun matchRoundScoresFirstTryPairsAndRecordsLearning() {
        val db = TestSupport.bundled()
        val cards = GameWords.pick(db, SeededGenerator(2u), MatchRound.SIZE)
        val round = MatchRound(cards, SeededGenerator(3u))
        assertEquals(cards.toSet(), round.left.toSet())
        assertEquals(cards.toSet(), round.right.toSet())
        assertFalse(round.pair(cards[0].id, cards[1].id))
        for (c in cards) assertTrue(round.pair(c.id, c.id))
        assertFalse(round.pair(cards[0].id, cards[0].id))
        assertTrue(round.isFinished)
        assertEquals(MatchRound.SIZE - 1, round.score)
        round.record(clock, db, 40)
        assertEquals(LearningState.STRUGGLING, LearningStore.state(cards[0].id, db).state)
        assertEquals(LearningState.LEARNED, LearningStore.state(cards[1].id, db).state)
        assertEquals(1, GameResults.playedToday(Game.MATCH, clock, db))
        assertEquals(MatchRound.SIZE, db.int("SELECT COUNT(*) FROM review_log WHERE source = 'match'"))
        assertEquals(1, StatsQueries.streak(db, clock))
    }
}
