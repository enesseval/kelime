package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.review.QuickReview
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Quick Review must not repeat the same words in the same order every round (docs/SYNC.md, 2026-11-18). */
class QuickReviewRotationTest {
    private val day = LocalDate.of(2026, 10, 20)

    private fun struggling20() = TestSupport.bundled().also { db ->
        for (id in db.strings("SELECT id FROM card WHERE level IN ('A2','B1') ORDER BY id LIMIT 20")) {
            CardState(id, LearningState.STRUGGLING, lastAnsweredOn = day).save(db)
        }
    }

    /** Five rounds on one database, every second card answered wrong. */
    @Test fun consecutiveRoundsKeepTheirDistanceAndOnlyWrongCardsReturn() {
        val db = struggling20()
        val rng = SeededGenerator(7u)
        var previous = emptyList<String>()
        var previousWrong = emptyList<String>()
        repeat(5) { round ->
            val ids = QuickReview.start(db, rng, today = day).map { it.id }
            assertEquals("round $round has 10 questions", 10, ids.size)
            assertEquals(10, ids.toSet().size)
            // (a) none of the first four is from the last round
            assertTrue("round $round head ${ids.take(4)} vs $previous", ids.take(4).none { it in previous })
            // (b) at most 3 of the last round, and only ones answered wrong there
            val again = ids.filter { it in previous }
            assertTrue("round $round again=$again", again.size <= 3)
            assertTrue("round $round again=$again wrong=$previousWrong", again.all { it in previousWrong })
            ids.forEachIndexed { i, id -> QuickReview.noteAnswer(db, id, correct = i % 2 == 0) }
            previous = ids
            previousWrong = ids.filterIndexed { i, _ -> i % 2 != 0 }
            assertEquals(previousWrong.toSet(), QuickReview.lastWrong(db).toSet())
        }
    }

    /** (c) twenty struggling words answered the same day: two rounds do not give one order. */
    @Test fun equalDaysAreShuffled() {
        val db = struggling20()
        val a = QuickReview.orderedIds(db, SeededGenerator(1u), today = day)
        val b = QuickReview.orderedIds(db, SeededGenerator(2u), today = day)
        assertEquals(a.toSet(), b.toSet())
        assertNotEquals(a, b)
        val ra = QuickReview.makeQuestions(db, SeededGenerator(1u), today = day).map { it.id }
        val rb = QuickReview.makeQuestions(db, SeededGenerator(2u), today = day).map { it.id }
        assertNotEquals(ra, rb)
        // Older days still come first.
        CardState(a.last(), LearningState.STRUGGLING, lastAnsweredOn = day.minusDays(5)).save(db)
        assertEquals(a.last(), QuickReview.orderedIds(db, SeededGenerator(3u), today = day).first())
    }

    /** (d) A pool of six: the round still has six questions, with the last round's cards filling in. */
    @Test fun aSmallPoolStillMakesAFullRound() {
        val six = listOf("a", "b", "c", "d", "e", "f")
        val rng = SeededGenerator(9u)
        val first = QuickReview.pickRound(six, emptyList(), emptyList(), rng)
        assertEquals(6, first.size)
        assertEquals(six.toSet(), first.toSet())
        val second = QuickReview.pickRound(six, first, listOf("a", "c"), rng)
        assertEquals(6, second.size)
        assertEquals(six.toSet(), second.toSet())
        // Fewer than six: whatever there is.
        assertEquals(2, QuickReview.pickRound(listOf("a", "b"), listOf("a", "b"), emptyList(), rng).size)
    }

    @Test fun theRoundIsRememberedAndCorrectAnswersNeverComeBack() {
        val db = struggling20()
        val rng = SeededGenerator(4u)
        val first = QuickReview.start(db, rng, today = day).map { it.id }
        assertEquals(first, QuickReview.lastRound(db))
        // All answered right: none of them comes in the next round while others are available.
        first.forEach { QuickReview.noteAnswer(db, it, correct = true) }
        val second = QuickReview.start(db, rng, today = day).map { it.id }
        assertTrue(second.none { it in first })
    }
}
