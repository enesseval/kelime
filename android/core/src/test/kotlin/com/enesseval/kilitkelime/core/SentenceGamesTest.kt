package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.games.GameResults
import com.enesseval.kilitkelime.core.games.GameWords
import com.enesseval.kilitkelime.core.games.GapFill
import com.enesseval.kilitkelime.core.games.GapFillGame
import com.enesseval.kilitkelime.core.games.SentenceCheck
import com.enesseval.kilitkelime.core.games.SentenceGame
import com.enesseval.kilitkelime.core.games.SentenceTokens
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

/** Cümle Kur and Boşluğu Doldur (docs/V1_2_PLAN.md §4). */
class SentenceGamesTest {
    private val clock = AppClock.fixed(Instant.parse("2026-11-14T10:00:00Z"), ZoneId.of("UTC"))

    private fun card(word: String, en: String, tr: String = "Bu bir örnek.", pos: PartOfSpeech = PartOfSpeech.NOUN, level: CEFRLevel = CEFRLevel.A1) =
        Card("a1-$word", word, pos, level, listOf("anlam"), en, tr)

    // ---- Cümle Kur

    @Test fun tokensKeepPunctuationOnTheLastWordAndOnlyTheFirstLosesItsCapital() {
        val t = SentenceTokens.tokens(card("idea", "I think this is a good idea."))!!
        assertEquals(listOf("I", "think", "this", "is", "a", "good", "idea."), t)
        val u = SentenceTokens.tokens(card("water", "Water is very important for us."))!!
        assertEquals("water", u.first())
        assertEquals("Water is very important for us.", SentenceTokens.sentence(u))
        assertEquals("Water", SentenceTokens.shown(u[0], 0))
        assertEquals("is", SentenceTokens.shown(u[1], 1))
        // Only the first place is capitalised; "I'm" and acronyms keep their capitals.
        assertEquals("I'm", SentenceTokens.tokens(card("tired", "I'm very tired of this."))!!.first())
        assertEquals("TV", SentenceTokens.tokens(card("tv", "TV is on in the room."))!!.first())
    }

    @Test fun onlyFourToTenWordSentencesAreUsable() {
        assertNull(SentenceTokens.tokens(card("a", "Too short here.")))
        assertNotNull(SentenceTokens.tokens(card("a", "Just four words here.")))
        assertNotNull(SentenceTokens.tokens(card("a", "One two three four five six seven eight nine ten.")))
        assertNull(SentenceTokens.tokens(card("a", "One two three four five six seven eight nine ten eleven.")))
        assertNull(SentenceTokens.tokens(card("a", "")))
        assertNull(SentenceTokens.tokens(card("a", "Four words in here.", tr = "")))
        // All words the same: no shuffle could differ.
        assertNull(SentenceTokens.tokens(card("a", "no no no no")))
    }

    @Test fun theShuffledOrderIsNeverTheRightOne() {
        for (seed in 1..300) {
            val rng = SeededGenerator(seed.toULong())
            for (sentence in listOf("a b c d", "a a b b", "I am a student.", "a b a b a b a b", "go go go home")) {
                val tokens = SentenceTokens.tokens(card("x", sentence)) ?: continue
                val order = SentenceTokens.shuffledOrder(tokens, rng)
                assertEquals(tokens.indices.toList(), order.sorted())
                assertNotEquals("$sentence seed $seed", tokens, order.map { tokens[it] })
            }
        }
    }

    private fun game(vararg sentences: String): SentenceGame =
        SentenceGame(sentences.mapIndexed { i, s -> card("w$i", s) }, SeededGenerator(7uL), sentences.size)

    /** Places the tiles in the order of the right sentence. */
    private fun SentenceGame.solve() {
        val item = current!!
        for (i in item.tokens.indices) place(item.tileOrder.indices.first { item.tileText(it) == item.tokens[i] && !placed(it) })
    }

    @Test fun twoTriesAndTheAnswersTheyRecord() {
        val g = game("I like green tea a lot.", "We go to school by bus.", "The cat is on the table.")
        // 1: right first time.
        g.solve()
        assertEquals(SentenceCheck.Correct, g.check())
        g.next()
        // 2: wrong, wrong again: the sentence is shown.
        val item = g.current!!
        for (tile in item.tileOrder.indices) g.place(tile) // the shuffled order is wrong
        val first = g.check()
        assertTrue(first is SentenceCheck.Wrong)
        assertFalse((first as SentenceCheck.Wrong).wrongPlaces.isEmpty())
        assertEquals(1, g.tries)
        assertEquals(SentenceCheck.Revealed, g.check())
        assertTrue(g.revealed)
        g.next()
        // 3: wrong, then fixed on the second try: correct, but not on the first try.
        val third = g.current!!
        for (tile in third.tileOrder.indices) g.place(tile)
        assertTrue(g.check() is SentenceCheck.Wrong)
        while (g.row.isNotEmpty()) g.remove(0)
        g.solve()
        assertEquals(SentenceCheck.Correct, g.check())
        g.next()
        assertTrue(g.isFinished)

        val db = TestSupport.bundled()
        val ids = g.items.map { it.card.id }
        // Cards need to exist for LearningStore; reuse real ones for the recording check.
        val real = GameWords.pick(db, SeededGenerator(3uL), 3, clock.today, SentenceTokens::usable)
        val g2 = SentenceGame(real, SeededGenerator(9uL), 3)
        g2.solve(); g2.check(); g2.next()
        repeat(2) { for (t in g2.current!!.tileOrder.indices) g2.place(t); g2.check(); if (it == 0) while (g2.row.isNotEmpty()) g2.remove(0) }
        g2.next()
        g2.solve(); g2.check(); g2.next()
        assertTrue(g2.isFinished)
        assertTrue(g2.record(60, clock, db))
        assertEquals(1, GameResults.playedToday(Game.SENTENCE, clock, db))
        // First and third were right first time, the second was shown.
        assertEquals(2, GameResults.best(Game.SENTENCE, db))
        assertEquals(3, real.map { LearningStore.state(it.id, db) }.size)
        assertEquals(3, ids.size)
    }

    @Test fun placingAndReturningCards() {
        val g = game("I like green tea a lot.")
        val item = g.current!!
        g.place(0); g.place(0) // the same card twice does nothing
        assertEquals(listOf(0), g.row)
        assertFalse(g.canCheck)
        for (t in item.tileOrder.indices) g.place(t)
        assertTrue(g.canCheck)
        g.remove(0)
        assertEquals(item.tokens.size - 1, g.row.size)
        assertFalse(g.canCheck)
    }

    // ---- Boşluğu Doldur

    @Test fun theWordMustAppearAsWrittenAndIsBlankedEverywhere() {
        assertEquals("I _____ this is a good idea.", GapFill.blanked(card("think", "I think this is a good idea.", pos = PartOfSpeech.VERB)))
        assertEquals("_____ is easy, _____ is fun.", GapFill.blanked(card("it", "It is easy, it is fun.")))
        assertNull(GapFill.blanked(card("think", "I thought it was easy.", pos = PartOfSpeech.VERB)))
        assertNull(GapFill.blanked(card("cat", "The cat's tail is long.")))
        assertNull(GapFill.blanked(card("can", "I can't go now.")))
        assertNull(GapFill.blanked(card("go", "We are going home.")))
    }

    @Test fun distractorsAreTheSamePosAndLevelAllDifferent() {
        val db = TestSupport.bundled()
        val rng = SeededGenerator(11uL)
        val cards = db.query("SELECT * FROM card", emptyList(), Card::from).filter { GapFill.usable(it) }.shuffledSample(150)
        for (c in cards) {
            val pool = GapFill.distractorPool(c, db)
            val q = GapFill.question(c, pool, rng) ?: continue
            assertEquals(GapFill.OPTIONS, q.options.size)
            assertEquals(GapFill.OPTIONS, q.options.map { it.lowercase() }.distinct().size)
            assertEquals(c.word, q.answer)
            val wrong = q.options.filter { it != c.word }
            assertEquals(3, wrong.size)
            for (w in wrong) {
                val source = pool.first { it.word == w }
                assertEquals(c.pos, source.pos)
                assertEquals(c.level, source.level)
                assertNotEquals(c.word.lowercase(), w.lowercase())
            }
        }
    }

    private fun <T> List<T>.shuffledSample(n: Int): List<T> = shuffled(java.util.Random(1)).take(n)

    @Test fun answeringCountsOnceAndRecords() {
        val db = TestSupport.bundled()
        val rng = SeededGenerator(5uL)
        val cards = GameWords.pick(db, rng, GapFillGame.POOL, clock.today, GapFill::usable)
        val questions = GapFill.questions(db, cards, rng)
        assertTrue(questions.size >= 5)
        val game = GapFillGame(questions)
        val q0 = game.current!!
        assertTrue(game.answer(q0.answerIndex))
        assertFalse("a question counts once", game.answer(q0.answerIndex))
        game.next()
        val q1 = game.current!!
        assertFalse(game.answer((q1.answerIndex + 1) % GapFill.OPTIONS))
        game.next()
        assertEquals(1, game.score)
        assertEquals(2, game.answered)
        assertEquals(listOf(q1.card.id), game.missedCards.map { it.id })
        assertTrue(game.record(40, clock, db))
        assertEquals(1, GameResults.best(Game.GAP_FILL, db))
        assertEquals(60, GapFillGame.SECONDS)
        assertEquals(1, GameResults.playedToday(Game.GAP_FILL, clock, db))
    }

    // ---- Uygunluk taraması: every card of the bundled content

    @Test fun eligibilityScanOverAllBundledCards() {
        val db = TestSupport.bundled()
        val all = db.query("SELECT * FROM card", emptyList(), Card::from)
        assertTrue("content has cards", all.size > 2000)
        var sentenceCards = 0
        var gapCards = 0
        val rng = SeededGenerator(1uL)
        val pools = mutableMapOf<Pair<String, String>, List<Card>>()
        for (card in all) {
            // Cümle Kur: never crashes, and a usable card always gives a shuffle that differs.
            val tokens = SentenceTokens.tokens(card)
            if (tokens != null) {
                sentenceCards++
                val order = SentenceTokens.shuffledOrder(tokens, rng)
                assertNotEquals(card.id, tokens, order.map { tokens[it] })
                assertEquals(card.id, tokens.size, order.size)
                val g = SentenceGame(listOf(card), rng, 1)
                assertEquals(1, g.items.size)
                assertTrue(g.items[0].tokens.size in SentenceTokens.MIN_WORDS..SentenceTokens.MAX_WORDS)
            }
            // Boşluğu Doldur: a usable card gives a question with its word in the options, or is left out cleanly.
            val blanked = GapFill.blanked(card)
            if (blanked != null) {
                assertTrue(card.id, blanked.contains(GapFill.BLANK))
                val pool = pools.getOrPut(card.pos.raw to card.level.raw) { GapFill.distractorPool(card, db) }
                val q = GapFill.question(card, pool, rng)
                if (q != null) {
                    gapCards++
                    assertEquals(card.id, GapFill.OPTIONS, q.options.distinct().size)
                    assertEquals(card.id, card.word, q.answer)
                }
            }
        }
        // The plan counted 2224 and 1831 usable cards; both games must keep nearly all of them.
        assertTrue("sentence cards: $sentenceCards", sentenceCards >= 2100)
        assertTrue("gap cards: $gapCards", gapCards >= 1700)
        // And a round from the default learner never comes out empty.
        for (level in CEFRLevel.entries) {
            val prefs = Preferences(level = level, enabledDecks = listOf(com.enesseval.kilitkelime.core.model.DeckID.A1))
            val withPrefs = TestSupport.bundled(prefs)
            val words = GameWords.pick(withPrefs, SeededGenerator(2uL), SentenceGame.POOL, clock.today, SentenceTokens::usable)
            if (words.isEmpty()) continue
            assertTrue(SentenceGame(words, SeededGenerator(2uL)).items.isNotEmpty())
        }
        val db2 = TestSupport.bundled()
        val words = GameWords.pick(db2, SeededGenerator(4uL), GapFillGame.POOL, clock.today, GapFill::usable)
        assertTrue(GapFill.questions(db2, words, SeededGenerator(4uL)).isNotEmpty())
        val sentenceWords = GameWords.pick(db2, SeededGenerator(4uL), SentenceGame.POOL, clock.today, SentenceTokens::usable)
        assertTrue(SentenceGame(sentenceWords, SeededGenerator(4uL)).items.size == SentenceGame.ROUND)
    }
}
