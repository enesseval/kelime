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
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.PartOfSpeech
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

    private fun matchCard(i: Int) = Card("c$i", "word$i", PartOfSpeech.NOUN, CEFRLevel.A1, listOf("anlam$i"), "", "")

    @Test fun matchGameScoresAndMisses() {
        val game = MatchGame((0 until 7).map(::matchCard), SeededGenerator(1u))
        val en1 = game.left.indexOfFirst { it?.id == "c1" }
        val tr0 = game.right.indexOfFirst { it?.id == "c0" }
        val en0 = game.left.indexOfFirst { it?.id == "c0" }
        assertFalse(game.pair(en1, tr0))
        assertTrue(game.pair(en0, tr0))
        assertEquals(1, game.score)
        assertEquals(listOf("c0"), game.firstTry)
        assertEquals(setOf("c1"), game.missedIDs)
        // The matched places stay empty until three are gone.
        assertNull(game.left[en0])
        assertNull(game.right[tr0])
    }

    @Test fun noPairStartsOnTheSameRow() {
        for (seed in 0uL until 200uL) {
            val game = MatchGame((0 until 10).map(::matchCard), SeededGenerator(seed))
            for (i in game.left.indices) assertTrue("seed $seed", game.left[i]?.id != game.right[i]?.id)
        }
    }

    /** iOS build 29 bug: a matched place refilled at once, so the newest cards were easy to spot. */
    @Test fun matchedSlotsRefillInBatches() {
        for (seed in 0uL until 50uL) {
            val game = MatchGame((0 until 30).map(::matchCard), SeededGenerator(seed))
            var rounds = 0
            while (!game.isEmpty && rounds < 200) {
                rounds++
                val i = game.left.indexOfFirst { en -> en != null && game.right.any { it?.id == en.id } }
                if (i < 0) break
                val card = game.left[i]!!
                val j = game.right.indexOfFirst { it?.id == card.id }
                val before = game.left.mapNotNull { it?.id }.toSet()
                assertTrue(game.pair(i, j))
                val empty = game.left.count { it == null }
                assertTrue("seed $seed round $rounds", empty < MatchGame.REFILL_AT || game.score > 25)
                for (k in game.left.indices) {
                    val c = game.left[k] ?: continue
                    if (c.id in before) continue
                    assertTrue("seed $seed round $rounds", game.right[k]?.id != c.id)
                }
            }
            assertEquals("seed $seed", 30, game.score)
            assertTrue(game.isEmpty)
        }
    }

    @Test fun matchRecordsLearningAndTheBestScore() {
        val db = TestSupport.bundled()
        val pool = GameWords.pick(db, SeededGenerator(2u), 8)
        val game = MatchGame(pool, SeededGenerator(3u))
        val word = game.left[0]!!
        assertFalse(game.pair(0, game.right.indexOfFirst { it != null && it.id != word.id }))
        assertTrue(game.pair(0, game.right.indexOf(word)))
        while (!game.isEmpty) {
            val i = game.left.indexOfFirst { en -> en != null && game.right.any { it?.id == en.id } }
            if (i < 0) break
            game.pair(i, game.right.indexOf(game.left[i]))
        }
        assertEquals(8, game.score)
        assertTrue(game.record(55, clock, db))
        assertEquals(LearningState.STRUGGLING, LearningStore.state(word.id, db).state)
        assertEquals(LearningState.LEARNED, LearningStore.state(game.firstTry.first(), db).state)
        assertEquals(8, GameResults.best(Game.MATCH, db))
        assertEquals(1, db.int("SELECT COUNT(*) FROM streak_day WHERE source = 'match'"))
    }
}
