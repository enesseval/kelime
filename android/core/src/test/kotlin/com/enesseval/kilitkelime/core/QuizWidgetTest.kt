package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.crossword.DailyPuzzleSummary
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.model.WidgetContent
import com.enesseval.kilitkelime.core.review.ReviewQuestion
import com.enesseval.kilitkelime.core.widgets.WidgetActions
import com.enesseval.kilitkelime.core.widgets.WidgetTimelineBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class QuizWidgetTest {
    private val istanbul = ZoneId.of("Europe/Istanbul")
    private val start = Instant.parse("2026-10-13T07:20:00Z")
    private fun clock(offset: Long = 0) = AppClock.fixed(start.plusSeconds(offset), istanbul)
    private fun quiz(db: JdbcSqlDb, offset: Long = 0) = WidgetTimelineBuilder.quiz(db, clock(offset), SeededGenerator(5u))

    @Test fun answerShowsForAMinuteThenTheNextQuestion() {
        val db = TestSupport.bundled()
        val before = quiz(db)
        val first = before[0].card!!
        val second = before[1].card!!
        assertNull(before[0].quizAnswer)
        assertEquals(true, WidgetActions.answerQuiz(first.id, first.word, db, clock(10)))

        val after = quiz(db, 20)
        assertEquals(first.id, after[0].card?.id)
        assertEquals(first.word, after[0].quizAnswer)
        assertEquals(second.id, after[1].card?.id)
        assertNull(after[1].quizAnswer)
        assertEquals(start.plusSeconds(10).plus(WidgetTimelineBuilder.quizResultDuration), after[1].date)
        assertEquals(after.map { it.date }.sorted(), after.map { it.date })

        assertEquals(false, WidgetActions.answerQuiz(second.id, "nope", db, clock(90)))

        val later = quiz(db, 300)
        assertNull(later[0].quizAnswer)
        assertTrue(later[0].card?.id != first.id && later[0].card?.id != second.id)
    }

    @Test fun widgetCanShowOnlyWordsOrOnlyPhrases() {
        for (content in listOf(WidgetContent.WORDS, WidgetContent.PHRASES)) {
            val db = TestSupport.bundled(Preferences(widgetContent = content))
            val cards = WidgetTimelineBuilder.build(db, clock(), SeededGenerator(3u)).mapNotNull { it.card }
            assertFalse(cards.isEmpty())
            assertTrue(cards.all { it.isPhrase == (content == WidgetContent.PHRASES) })
        }
    }

    @Test fun contentSettingIsSaved() {
        val db = TestSupport.bundled(Preferences(widgetContent = WidgetContent.PHRASES))
        assertEquals(WidgetContent.PHRASES, Preferences.load(db).widgetContent)
    }

    @Test fun closeMissesGetAHint() {
        val q = ReviewQuestion(Card("x", "woman", PartOfSpeech.NOUN, CEFRLevel.A1, listOf("kadın"), "", ""), ReviewQuestion.Kind.Write)
        assertTrue(q.mistakeHint("women")!!.contains("4. harf"))
        assertTrue(q.mistakeHint("wmoan")!!.contains("yeri karışmış"))
        assertNull(q.mistakeHint("woman"))
        assertNull(q.mistakeHint(""))
        assertNull(q.mistakeHint("wxyzq"))
        assertEquals(listOf(3), ReviewQuestion.wrongPositions("women", "woman"))
    }

    @Test fun puzzleSummaryKeepsItsThumbnail() {
        val db = TestSupport.database()
        val summary = DailyPuzzleSummary(LocalDate.of(2026, 10, 13), 1, 3, mapOf(0 to true, 1 to false, 9 to true))
        summary.save(db)
        assertEquals(summary, DailyPuzzleSummary.load(db))
        Settings.set(db, SettingKey.DAILY_PUZZLE_SUMMARY, "2026-10-13|2|5")
        val old = DailyPuzzleSummary.load(db)
        assertTrue(old?.solved == 2 && old.cells.isEmpty())
    }

    @Test fun turkishIDoesNotBreakAnswers() {
        val q = ReviewQuestion(Card("x", "ice", PartOfSpeech.NOUN, CEFRLevel.A1, listOf("buz"), "", ""), ReviewQuestion.Kind.Write)
        val previous = java.util.Locale.getDefault()
        java.util.Locale.setDefault(java.util.Locale.forLanguageTag("tr-TR"))
        try {
            assertTrue(q.isCorrect("ICE"))
            assertTrue(q.isCorrect(" ice "))
            assertEquals("ICE", ReviewQuestion.asciiUpper("ice"))
        } finally {
            java.util.Locale.setDefault(previous)
        }
    }
}
