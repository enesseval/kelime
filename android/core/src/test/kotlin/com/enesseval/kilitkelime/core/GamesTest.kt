package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.games.GameResults
import com.enesseval.kilitkelime.core.games.GameWords
import com.enesseval.kilitkelime.core.games.MatchGame
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
import java.time.LocalDate
import java.time.ZoneId

class GamesTest {
    private val clock = AppClock.fixed(Instant.parse("2026-10-14T09:00:00Z"), ZoneId.of("Europe/Istanbul"))

    @Test fun gameWordsFollowThePlanOrder() {
        val db = TestSupport.bundled()
        val today = clock.today
        CardState("b1-avoid", LearningState.STRUGGLING).save(db)
        CardState("b1-quite", LearningState.NEW, lastShownAt = clock.now.minusSeconds(3600), timesShown = 1).save(db)
        CardState("b1-nearly", LearningState.LEARNED, 1, lastAnsweredOn = today.minusDays(5)).save(db)
        val words = GameWords.pick(db, SeededGenerator(1u), 6, today)
        assertEquals(listOf("b1-avoid", "b1-quite", "b1-nearly"), words.take(3).map { it.id })
        assertEquals(6, words.size)
        val meanings = words.map { Card.normalizedMeanings(it.tr) }
        assertEquals(meanings.sumOf { it.size }, meanings.flatten().toSet().size)
    }

    @Test fun wordHuntHidesForwardWordsOfThreeToEightLetters() {
        val db = TestSupport.bundled()
        for (size in listOf(WordHunt.SIZE, WordHunt.SMALL_SIZE)) for (seed in 0uL until 40uL) {
            val rng = SeededGenerator(seed)
            val hunt = WordHunt.make(GameWords.pick(db, rng, 24) { WordHunt.usable(it, size) }, rng, size)
            assertNotNull(hunt)
            hunt!!
            assertEquals(size * size, hunt.letters.size)
            assertTrue(hunt.words.size in 3..WordHunt.WORDS)
            for (w in hunt.words) {
                assertTrue(w.answer.length in 3..minOf(8, size))
                assertTrue("forwards only", w.dRow >= 0 && w.dCol >= 0)
                assertEquals(w.answer, w.cells.joinToString("") { (r, c) -> hunt.letter(r, c).toString() })
                assertEquals(w, hunt.match(w.cells.last(), w.cells.first()))
                assertEquals(w.cells.first(), w.firstCell)
            }
            assertTrue(hunt.letters.all { it in 'A'..'Z' })
        }
    }

    @Test fun wordHuntIsDeterministicForASeed() {
        val db = TestSupport.bundled()
        fun make(seed: ULong): WordHunt? {
            val rng = SeededGenerator(seed)
            return WordHunt.make(GameWords.pick(db, rng, 24) { WordHunt.usable(it) }, rng)
        }
        assertEquals(make(9u), make(9u))
    }

    @Test fun wordHuntRecordsUnhintedWordsAndTheStreak() {
        val db = TestSupport.bundled()
        val rng = SeededGenerator(4u)
        val hunt = WordHunt.make(GameWords.pick(db, rng, 24) { WordHunt.usable(it) }, rng)!!
        val (a, b) = hunt.words.take(2).map { it.card.id }
        assertTrue(hunt.record(setOf(a, b), hinted = setOf(b), seconds = 50, clock = clock, db = db))
        assertEquals(LearningState.LEARNED, LearningStore.state(a, db).state)
        assertEquals(LearningState.NEW, LearningStore.state(b, db).state) // the hint itself is recorded when used
        assertEquals(1, StatsQueries.streak(db, clock))
        assertEquals(2, GameResults.best(Game.WORD_HUNT, db))
        assertNull(WordHunt.make(listOf(TestSupport.card("cat")), SeededGenerator(1u)))
    }

    @Test fun matchRefillsTheBoardAndScoresPairs() {
        val db = TestSupport.bundled()
        val pool = GameWords.pick(db, SeededGenerator(2u), 8)
        val game = MatchGame(pool, SeededGenerator(3u))
        assertEquals(pool.take(5), game.left)
        assertEquals(pool.take(5).toSet(), game.right.filterNotNull().toSet())
        // A wrong pair: the word becomes missed.
        val word = game.left[0]!!
        val wrongIndex = game.right.indexOfFirst { it != null && it.id != word.id }
        assertFalse(game.pair(0, wrongIndex))
        // Correct pairs: a new pair fills both freed places.
        assertTrue(game.pair(0, game.right.indexOf(word)))
        assertEquals(pool[5], game.left[0])
        assertTrue(pool[5] in game.right)
        repeat(7) {
            val i = game.left.indexOfFirst { it != null }
            game.pair(i, game.right.indexOf(game.left[i]))
        }
        assertTrue(game.isEmpty)
        assertEquals(8, game.score)
        assertTrue(game.record(55, clock, db))
        assertEquals(LearningState.STRUGGLING, LearningStore.state(word.id, db).state)
        assertEquals(LearningState.LEARNED, LearningStore.state(pool[1].id, db).state)
        assertEquals(8, GameResults.best(Game.MATCH, db))
        assertEquals(1, db.int("SELECT COUNT(*) FROM streak_day WHERE source = 'match'"))
        assertEquals(LocalDate.of(2026, 10, 14), clock.today)
    }
}
