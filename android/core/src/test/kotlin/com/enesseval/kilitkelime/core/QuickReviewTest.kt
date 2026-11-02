package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.review.PlacementTest
import com.enesseval.kilitkelime.core.review.QuickReview
import com.enesseval.kilitkelime.core.review.ReviewQuestion
import com.enesseval.kilitkelime.core.review.ReviewSession
import com.enesseval.kilitkelime.core.widgets.SampleContent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class QuickReviewTest {
    private fun questions(db: JdbcSqlDb, seed: ULong = 1u) = QuickReview.makeQuestions(db, SeededGenerator(seed))

    @Test fun tenQuestionsFromEntitledDecks() {
        val qs = questions(TestSupport.bundled())
        assertEquals(10, qs.size)
        assertEquals(10, qs.map { it.id }.toSet().size)
        assertTrue(qs.all { it.card.level in listOf(CEFRLevel.A2, CEFRLevel.B1) })
    }

    @Test fun orderIsStrugglingThenShownNewThenNew() {
        val db = TestSupport.bundled()
        CardState("b1-avoid", LearningState.STRUGGLING, lastAnsweredOn = LocalDate.of(2026, 10, 12)).save(db)
        CardState("b1-quite", LearningState.STRUGGLING, lastAnsweredOn = LocalDate.of(2026, 10, 10)).save(db)
        CardState("b1-nearly", LearningState.NEW, timesShown = 2).save(db)
        CardState("b1-proud", LearningState.LEARNED).save(db)
        val ids = questions(db).map { it.id }
        assertEquals(listOf("b1-quite", "b1-avoid", "b1-nearly"), ids.take(3))
        assertFalse("b1-proud" in ids)
    }

    @Test fun dueWordsComeAfterStruggling() {
        val db = TestSupport.bundled()
        val today = LocalDate.of(2026, 10, 20)
        CardState("b1-avoid", LearningState.STRUGGLING, lastAnsweredOn = today.minusDays(1)).save(db)
        CardState("b1-nearly", LearningState.LEARNED, 1, lastAnsweredOn = today.minusDays(5)).save(db)
        val ids = QuickReview.makeQuestions(db, SeededGenerator(1u), today = today).map { it.id }
        assertEquals(listOf("b1-avoid", "b1-nearly"), ids.take(2))
    }

    @Test fun learnedWordsFillShortDecks() {
        val db = TestSupport.bundled()
        for (id in db.strings("SELECT id FROM card WHERE level IN ('A2','B1')")) CardState(id, LearningState.LEARNED).save(db)
        assertEquals(10, questions(db).size)
    }

    @Test fun questionKindsAndOptions() {
        val qs = questions(TestSupport.bundled(), 3u)
        qs.forEachIndexed { i, q ->
            when (val kind = q.kind) {
                is ReviewQuestion.Kind.Meaning -> {
                    assertEquals(4, kind.options.size)
                    assertTrue(q.card.word in kind.options)
                    assertEquals(4, kind.options.toSet().size)
                }
                ReviewQuestion.Kind.Write -> {
                    assertEquals(1, i % 3)
                    assertTrue(q.card.word.length <= QuickReview.MAX_WRITE_LENGTH)
                }
            }
        }
        assertTrue(qs.any { it.kind == ReviewQuestion.Kind.Write })
    }

    @Test fun blankedSentenceAndAnswerCheck() {
        val q = ReviewQuestion(SampleContent.hesitate, ReviewQuestion.Kind.Write)
        assertEquals("Don't ________ to ask.", q.blankedSentence)
        assertTrue(q.isCorrect("HESITATE"))
        assertTrue(q.isCorrect("hesitate "))
        assertFalse(q.isCorrect("hesitat"))
        assertTrue(ReviewQuestion(SampleContent.reliable, ReviewQuestion.Kind.Write).isCorrect("reliable"))
        assertEquals("RELIABLE", ReviewQuestion.asciiUpper("reliable"))
        val pursue = ReviewQuestion(Card("b2-pursue", "pursue", PartOfSpeech.VERB, CEFRLevel.B2, listOf("x"), "Pursue your dreams.", "y"), ReviewQuestion.Kind.Write)
        assertEquals("________ your dreams.", pursue.blankedSentence)
    }

    @Test fun sessionFlowAndSummary() {
        val qs = listOf(SampleContent.reluctant, SampleContent.reliable, SampleContent.hesitate).map { ReviewQuestion(it, ReviewQuestion.Kind.Write) }
        val s = ReviewSession(qs, "s")
        assertEquals("b2-reluctant", s.current?.id)
        s.record(true, LearningState.NEW, LearningState.LEARNED)
        s.record(false, LearningState.NEW, LearningState.STRUGGLING)
        assertTrue(s.awaitingContinue && s.results.size == 1)
        s.advance()
        s.record(false, LearningState.NEW, LearningState.STRUGGLING)
        s.advance()
        s.record(true, LearningState.STRUGGLING, LearningState.STRUGGLING)
        s.advance()
        assertTrue(s.isFinished)
        assertNull(s.current)
        assertEquals(2, s.score)
        assertEquals(listOf("reluctant"), s.newlyLearned.map { it.word })
        assertEquals(listOf("reliable"), s.newlyStruggling.map { it.word })
        assertEquals(1.0, s.progress, 0.0)
    }

    @Test fun placementEveryLevelHasTwoQuestionsWithFourMeanings() {
        val questions = PlacementTest.questions(TestSupport.bundled(), SeededGenerator(3u))
        assertEquals(CEFRLevel.entries.toSet(), questions.keys)
        for (list in questions.values) {
            assertEquals(2, list.size)
            for (q in list) assertTrue(q.options.size == 4 && q.options.toSet().size == 4 && q.answer in q.options)
        }
    }

    @Test fun placementStopsAfterTwoMissedLevelsAndPicksTheHighestKnown() {
        val all = CEFRLevel.entries
        val a1 = CEFRLevel.A1; val a2 = CEFRLevel.A2; val b1 = CEFRLevel.B1; val b2 = CEFRLevel.B2
        assertEquals(a1, PlacementTest.nextLevel(emptyList(), all))
        assertEquals(b1, PlacementTest.nextLevel(listOf(a1 to 2, a2 to 2), all))
        assertNull(PlacementTest.nextLevel(listOf(a1 to 2, a2 to 2, b1 to 1, b2 to 0), all))
        assertEquals(a2, PlacementTest.result(listOf(a1 to 2, a2 to 2, b1 to 1, b2 to 0), all))
        assertEquals(b2, PlacementTest.nextLevel(listOf(a1 to 2, a2 to 1, b1 to 2), all))
        assertEquals(a1, PlacementTest.result(listOf(a1 to 0, a2 to 0), all))
        assertEquals(CEFRLevel.C2, PlacementTest.result(all.map { it to 2 }, all))
    }
}
