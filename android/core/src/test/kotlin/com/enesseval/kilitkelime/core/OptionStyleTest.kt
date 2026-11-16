package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.games.MatchGame
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.OptionStyle
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.Card
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Choices must not give the answer away by their ending punctuation or capitals (docs/SYNC.md, 2026-11-17). */
class OptionStyleTest {
    @Test fun theEndingIsTheLastMeaningfulCharacter() {
        assertEquals(OptionStyle.Ending.QUESTION, OptionStyle.ending("How are you?"))
        assertEquals(OptionStyle.Ending.QUESTION, OptionStyle.ending("Did he say \"yes?\" "))
        assertEquals(OptionStyle.Ending.QUESTION, OptionStyle.ending("(Is it ready?)"))
        assertEquals(OptionStyle.Ending.EXCLAMATION, OptionStyle.ending("Watch out!"))
        assertEquals(OptionStyle.Ending.PLAIN, OptionStyle.ending("See you later."))
        assertEquals(OptionStyle.Ending.PLAIN, OptionStyle.ending("see you later"))
        assertEquals(OptionStyle.Ending.PLAIN, OptionStyle.ending(""))
    }

    @Test fun stripRemovesTheEndingAndItsRepeats() {
        assertEquals("How are you", OptionStyle.stripEnding("How are you?"))
        assertEquals("Really", OptionStyle.stripEnding("Really?!"))
        assertEquals("Well", OptionStyle.stripEnding("Well... "))
        assertEquals("Hi, there", OptionStyle.stripEnding("Hi, there!"))
        assertEquals("?", OptionStyle.stripEnding("?"))
    }

    @Test fun alikeChoicesAreShownAsWritten() {
        val options = listOf("How are you?", "What is this?", "Who is that?", "Where is it?")
        assertEquals(options, OptionStyle.display(options))
        val words = listOf("hungry", "happy", "tired", "angry")
        assertEquals(words, OptionStyle.display(words))
    }

    @Test fun differentEndingsAreAllStripped() {
        val shown = OptionStyle.display(listOf("How are you?", "Watch out!", "See you later.", "take care"))
        assertEquals(listOf("How are you", "Watch out", "See you later", "Take care"), shown)
        assertTrue(OptionStyle.endingsAlike(shown))
    }

    @Test fun capitalsAreEvenedOutForPhrases() {
        // Sentences: all capital.
        assertEquals(listOf("Come on", "Take care", "Look out", "Hurry up"), OptionStyle.display(listOf("Come on!", "take care", "look out.", "hurry up")))
        // Phrases without punctuation: all small, "I" and acronyms kept.
        assertEquals(listOf("come on", "I mean it", "TV show", "hurry up"), OptionStyle.display(listOf("Come on", "I mean it", "TV show", "hurry up")))
        // Already alike (all capital): untouched.
        assertEquals(listOf("Come on", "I mean it"), OptionStyle.display(listOf("Come on", "I mean it")))
        // A leading ellipsis is skipped when the first letter is looked for.
        assertEquals(listOf("A hot potato.", "…, As it were"), OptionStyle.display(listOf("A hot potato.", "…, as it were")))
        // Single words are left as written (a proper noun keeps its capital).
        assertEquals(listOf("Monday", "table", "chair", "window"), OptionStyle.display(listOf("Monday", "table", "chair", "window")))
    }

    @Test fun theChoiceIsShownLikeItsPlaceInTheList() {
        val options = listOf("How are you?", "Watch out!")
        assertEquals("Watch out", OptionStyle.display("Watch out!", options))
        assertEquals("nope", OptionStyle.display("nope", options))
    }

    private fun looksAlike(shown: List<String>): Boolean {
        if (!OptionStyle.endingsAlike(shown)) return false
        val multi = shown.filter { s -> s.trim().any { it.isWhitespace() } }
        return multi.mapNotNull { it.firstOrNull { c -> c.isLetter() } }.map { it.isUpperCase() }.distinct().size <= 1
    }

    /** Every card of cards.json as the question: the right choice cannot be told by the end or the capital. */
    @Test fun noQuestionOfTheBundledCardsGivesTheAnswerAwayByItsWriting() {
        val db = TestSupport.bundled()
        val cards = db.query("SELECT * FROM card WHERE id NOT LIKE 'user-%'", emptyList(), Card::from)
        assertTrue(cards.size > 1000)
        val rng = SeededGenerator(11u)
        var phrases = 0
        var sameType = 0
        for (card in cards) {
            for (count in listOf(4, 2)) {
                val options = CardQueries.quizOptions(card, count, db, rng)
                assertTrue("answer missing for ${card.id}", card.word in options)
                val shown = OptionStyle.display(options)
                assertTrue("writing gives ${card.id} away: $shown", looksAlike(shown))
                // The choices are kept as the real words, so the answer is still found by its text.
                assertEquals(options.size, shown.size)
                if (count == 4 && card.isPhrase) {
                    phrases++
                    if (options.all { OptionStyle.sameEnding(it, card.word) }) sameType++
                }
            }
        }
        // Most phrase questions find three of the same kind; the rest are stripped.
        assertTrue("phrases=$phrases sameType=$sameType", phrases > 0 && sameType * 2 > phrases)
    }

    @Test fun wrongChoicesComeFromTheAnswersOwnSentenceType() {
        val db = TestSupport.bundled()
        val rng = SeededGenerator(5u)
        val question = db.query("SELECT * FROM card WHERE pos = 'phrase' AND word LIKE '%?'", emptyList(), Card::from)
        assertTrue(question.isNotEmpty())
        var checked = 0
        for (card in question.take(40)) {
            val wrong = CardQueries.distractors(card, 3, db, rng)
            if (wrong.all { OptionStyle.ending(it) == OptionStyle.Ending.QUESTION }) checked++
        }
        assertTrue("question phrases keep question choices: $checked of ${minOf(40, question.size)}", checked * 2 > minOf(40, question.size))
    }

    @Test fun theMatchBoardWritesEveryCardAlike() {
        val db = TestSupport.bundled()
        val rng = SeededGenerator(3u)
        val cards = db.query("SELECT * FROM card WHERE pos = 'phrase' AND id NOT LIKE 'user-%' ORDER BY id LIMIT 12", emptyList(), Card::from)
        val game = MatchGame(cards, rng)
        val english = cards.map { game.englishText(it) }
        val turkish = cards.map { game.turkishText(it) }
        assertTrue("english $english", looksAlike(english))
        assertTrue("turkish $turkish", looksAlike(turkish))
        assertFalse(english.any { it.isEmpty() } || turkish.any { it.isEmpty() })
    }
}
