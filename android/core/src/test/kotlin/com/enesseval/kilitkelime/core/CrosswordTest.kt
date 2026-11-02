package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.crossword.Crossword
import com.enesseval.kilitkelime.core.crossword.CrosswordDirection.ACROSS
import com.enesseval.kilitkelime.core.crossword.CrosswordDirection.DOWN
import com.enesseval.kilitkelime.core.crossword.CrosswordEntry
import com.enesseval.kilitkelime.core.crossword.CrosswordGame
import com.enesseval.kilitkelime.core.crossword.CrosswordGenerator
import com.enesseval.kilitkelime.core.crossword.CrosswordValidator
import com.enesseval.kilitkelime.core.crossword.CrosswordValidator.Problem
import com.enesseval.kilitkelime.core.crossword.DailyPuzzle
import com.enesseval.kilitkelime.core.crossword.GridPoint
import com.enesseval.kilitkelime.core.crossword.PuzzleStore
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.learning.shuffledWith
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.LearningState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneOffset

class CrosswordTest {
    companion object {
        val sample = Crossword("sample", 8, 10, listOf(
            CrosswordEntry(1, ACROSS, 0, 2, "BORROW", "a2-borrow"),
            CrosswordEntry(2, DOWN, 0, 3, "OBVIOUS", "b1-obvious"),
            CrosswordEntry(3, ACROSS, 3, 0, "HESITATE", "b2-hesitate"),
            CrosswordEntry(4, DOWN, 3, 5, "ACHIEVE", "b1-achieve"),
            CrosswordEntry(5, ACROSS, 9, 1, "ANCIENT", "b1-ancient"),
        ))

        val cards: Map<String, Card> by lazy { ContentImporter.decode(TestSupport.bundledText).cards.associate { it.id to it.card } }

        fun fill(entry: CrosswordEntry, game: CrosswordGame) {
            game.focus(entry)
            for ((cell, letter) in entry.cells.zip(entry.letters)) if (game.typed[cell] == null) game.type(letter)
        }
    }

    private fun Crossword.withEntry(i: Int, f: (CrosswordEntry) -> CrosswordEntry) = copy(entries = entries.mapIndexed { j, e -> if (j == i) f(e) else e })

    @Test fun sampleGridIsValid() = assertTrue(CrosswordValidator.problems(sample).isEmpty())

    @Test fun validatorCatchesBrokenGrids() {
        assertTrue(Problem.Conflict(GridPoint(0, 3)) in CrosswordValidator.problems(sample.withEntry(1) { it.copy(answer = "XBVIOUS") }))
        assertFalse(CrosswordValidator.isValid(sample.copy(entries = sample.entries + CrosswordEntry(6, ACROSS, 1, 4, "AB", "x"))))
        assertTrue(Problem.OutOfBounds("3a") in CrosswordValidator.problems(sample.withEntry(2) { it.copy(col = 3) }))
        assertTrue(Problem.BadNumbering("9a") in CrosswordValidator.problems(sample.withEntry(4) { it.copy(number = 9) }))
    }

    @Test fun dailyPickWrapsAndIsStable() {
        val puzzles = (0 until 3).map { Crossword("p$it", 1, 1, emptyList()) }
        val day = LocalDates.EPOCH
        assertEquals("p0", DailyPuzzle.pick(puzzles, day)?.id)
        assertEquals("p1", DailyPuzzle.pick(puzzles, day.addingDays(4))?.id)
        assertEquals("p2", DailyPuzzle.pick(puzzles, day.addingDays(-1))?.id)
        assertEquals("p0", DailyPuzzle.pick(puzzles, day.addingDays(3000))?.id)
        assertNull(DailyPuzzle.pick(emptyList(), day))
        assertEquals("daily-B1-2026-01-01", DailyPuzzle.key(CEFRLevel.B1, day))
        assertEquals(CEFRLevel.A2, DailyPuzzle.level(CEFRLevel.A1, listOf(CEFRLevel.A2, CEFRLevel.B1)))
        assertEquals(CEFRLevel.B2, DailyPuzzle.level(CEFRLevel.B2, listOf(CEFRLevel.A2, CEFRLevel.B2)))
        assertEquals("tereddüt etmek (8)", DailyPuzzle.clue("tereddüt etmek", 8))
    }

    @Test fun storedGridJsonUsesTheIOSKeys() {
        val text = com.enesseval.kilitkelime.core.model.Json.encodeToString(Crossword.serializer(), sample)
        assertTrue(text.contains("\"n\":1") && text.contains("\"dir\":\"a\"") && text.contains("\"card_id\":\"a2-borrow\""))
        assertEquals(sample, com.enesseval.kilitkelime.core.model.Json.decodeFromString(Crossword.serializer(), text))
    }

    @Test fun typingFillsTheActiveWordAndJumpsAhead() {
        val game = CrosswordGame(sample)
        assertEquals("1a", game.activeEntry.id)
        "borrow".forEach(game::type)
        assertTrue(game.isSolved(sample.entries[0]))
        assertEquals("2d", game.activeEntry.id)
        game.focus(sample.entries.first { it.id == "1a" })
        game.select(GridPoint(0, 3))
        assertEquals("2d", game.activeEntry.id)
        assertNotEquals(GridPoint(0, 3), game.cursor)
        assertEquals(1, game.solvedCount)
    }

    @Test fun lettersUseASCIIUppercase() {
        val game = CrosswordGame(sample)
        game.select(GridPoint(3, 0))
        "hesitate".forEach(game::type)
        assertTrue(game.isSolved(sample.entries[2]))
        assertEquals('I', game.typed[GridPoint(3, 3)])
    }

    @Test fun deleteAndDirectionToggle() {
        val game = CrosswordGame(sample)
        game.type('B'); game.type('Q')
        game.deleteBackward()
        assertNull(game.typed[GridPoint(0, 3)])
        game.deleteBackward()
        assertNull(game.typed[GridPoint(0, 2)])
        game.select(GridPoint(0, 3))
        assertEquals("1a", game.activeEntry.id)
        game.select(GridPoint(0, 3))
        assertEquals("2d", game.activeEntry.id)
    }

    @Test fun hintsMarkWordsHelped() {
        val game = CrosswordGame(sample)
        game.select(GridPoint(3, 0))
        game.type('H'); game.type('A')
        assertTrue(game.checkWord())
        assertEquals(setOf(GridPoint(3, 1)), game.wrong)
        assertEquals(setOf("3a"), game.helped)
        game.select(GridPoint(3, 1))
        game.type('E')
        assertTrue(game.wrong.isEmpty())
        game.step(1)
        assertEquals("4d", game.activeEntry.id)
        game.step(1)
        assertEquals("5a", game.activeEntry.id)
        game.revealLetter()
        assertEquals(1, game.revealed.size)
        assertEquals(GridPoint(9, 2), game.cursor)
        game.revealWord()
        assertTrue(game.isSolved(sample.entries[4]))
        assertEquals(setOf("3a", "5a"), game.helped)
        assertEquals(3, game.hintsUsed)
        val clean = CrosswordGame(sample)
        clean.type('B')
        assertFalse(clean.checkWord())
        assertTrue(clean.helped.isEmpty())
    }

    @Test fun completionAndSnapshotRoundTrip() {
        val game = CrosswordGame(sample)
        for (entry in sample.orderedEntries) {
            if (entry.id == "4d") { game.focus(entry); game.revealWord(); continue }
            fill(entry, game)
        }
        assertTrue(game.isComplete)
        assertEquals(listOf("1a", "3a", "5a", "2d"), game.unaidedEntries.map { it.id })
        val restored = CrosswordGame.restore(sample, CrosswordGame.decodeSnapshot(game.encodedSnapshot()))
        assertTrue(restored.isComplete)
        assertEquals(setOf("4d"), restored.helped)
        assertEquals(1, restored.hintsUsed)
    }

    @Test fun storePersistsAndRecordsLearning() {
        val db = TestSupport.bundled()
        val clock = AppClock.fixed(Instant.ofEpochSecond(1_800_000_000), ZoneOffset.UTC)
        val game = CrosswordGame(sample)
        game.focus(sample.entries[2])
        val helped = game.revealLetter()
        PuzzleStore.recordHint(helped, clock, db)
        PuzzleStore.save("k", game, 42, null, db)
        val saved = PuzzleStore.load("k", sample, db)
        assertEquals(42, saved.seconds)
        assertEquals(1, saved.game.revealed.size)
        assertEquals(LearningState.STRUGGLING, LearningStore.state("b2-hesitate", db).state)
        val finished = CrosswordGame(sample)
        sample.orderedEntries.forEach { fill(it, finished) }
        assertTrue(finished.isComplete)
        PuzzleStore.recordCompletion(finished, clock, db)
        assertEquals(LearningState.LEARNED, LearningStore.state("a2-borrow", db).state)
    }

    @Test fun progressSavedForAnotherGridIsIgnored() {
        val db = TestSupport.database()
        val game = CrosswordGame(sample)
        game.focus(sample.entries[0])
        game.revealWord()
        PuzzleStore.save("k", game, 90, null, db)
        val moved = sample.withEntry(0) { it.copy(answer = it.answer.reversed()) }
        val other = PuzzleStore.load("k", moved, db)
        assertTrue(other.game.typed.isEmpty() && other.game.revealed.isEmpty() && other.seconds == 0)
        val same = PuzzleStore.load("k", sample, db)
        assertTrue(same.game.revealed.size == sample.entries[0].length && same.seconds == 90)
        db.execute("UPDATE puzzle_progress SET cells = ? WHERE puzzle_key = 'k'",
            listOf("""{"typed":{"0,0":"X"},"revealed":["0,0"],"wrong":[],"helped":[],"hintsUsed":1}"""))
        assertTrue(PuzzleStore.load("k", sample, db).game.typed.isEmpty())
        PuzzleStore.reset("k", db)
        assertEquals(0, db.int("SELECT COUNT(*) FROM puzzle_progress"))
    }

    @Test fun generatorSkipsWordsWithTheSameMeaning() {
        val develop = CrosswordGenerator.Word(cards.getValue("b1-develop"))
        val improve = CrosswordGenerator.Word(cards.getValue("b1-improve"))
        assertTrue(develop.meanings.intersect(improve.meanings).isNotEmpty())
        val fillers = cards.values.filter { it.level == CEFRLevel.B1 && it.word.length <= 10 }.sortedBy { it.id }.map(CrosswordGenerator::Word)
        for (seed in 0uL until 200uL) {
            val puzzle = CrosswordGenerator.generate("x", listOf(develop, improve), fillers, seed)
            assertNotNull(puzzle)
            val ids = puzzle!!.entries.map { it.cardID }.toSet()
            assertFalse("b1-develop" in ids && "b1-improve" in ids)
        }
    }

    @Test fun generatorIsDeterministicAndValid() {
        val words = cards.values.filter { it.level == CEFRLevel.B1 && it.word.length <= 10 }.sortedBy { it.id }.map(CrosswordGenerator::Word)
        val seeds = words.take(4)
        val a = CrosswordGenerator.generate("x", seeds, words, 99u)
        val b = CrosswordGenerator.generate("x", seeds, words, 99u)
        assertNotNull(a)
        assertEquals(a, b)
        assertTrue(CrosswordValidator.problems(a!!).isEmpty())
        assertTrue(a.entries.size >= 6)
        assertTrue(a.entries.map { it.cardID }.containsAll(seeds.map { it.cardID }))
    }

    /** 10,000 randomized generations: all valid, ≥ 90 % place all 4 seeds, all succeed with fallback. */
    @Test fun tenThousandPersonalGenerations() {
        val all = cards.values.filter { it.isSingleWord && it.word.length <= 10 }.sortedBy { it.id }.map(CrosswordGenerator::Word)
        val meaningsByID = all.associate { it.cardID to it.meanings }
        val rng = SeededGenerator(2026u)
        var withFourSeeds = 0
        val runs = 10_000
        for (run in 0 until runs) {
            val pool = all.shuffledWith(rng)
            val seeds = pool.take(4)
            val fillers = pool.drop(4).take(80)
            val puzzle = CrosswordGenerator.generate("p$run", seeds, fillers, run.toULong())
            assertNotNull("run $run failed", puzzle)
            assertTrue("run $run invalid", CrosswordValidator.isValid(puzzle!!))
            assertTrue(puzzle.width <= 10 && puzzle.height <= 10 && puzzle.entries.size >= 6)
            val meanings = puzzle.entries.map { meaningsByID[it.cardID] ?: emptySet() }
            assertEquals("run $run repeats a clue", meanings.sumOf { it.size }, meanings.flatten().toSet().size)
            if (puzzle.entries.map { it.cardID }.containsAll(seeds.map { it.cardID })) withFourSeeds++
        }
        assertTrue("rate ${withFourSeeds.toDouble() / runs}", withFourSeeds.toDouble() / runs >= 0.9)
    }
}
