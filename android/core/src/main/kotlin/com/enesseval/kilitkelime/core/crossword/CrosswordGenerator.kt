package com.enesseval.kilitkelime.core.crossword

import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.learning.intIn
import com.enesseval.kilitkelime.core.learning.randomElementWith
import com.enesseval.kilitkelime.core.learning.shuffledWith
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.review.ReviewQuestion

/**
 * Builds free-form crosswords on device (port of `CrosswordGenerator.swift`). Words cross only on
 * matching letters, nothing touches unless it crosses, the result fits 10 × 10 with at least 6
 * words (aiming for 7). Deterministic for a seed, with the same numbers as iOS.
 */
object CrosswordGenerator {
    const val MAX_SIZE = 10
    const val MIN_WORDS = 6
    const val TARGET_WORDS = 7
    const val ATTEMPTS = 40
    const val MAX_WORDS = 9

    data class Word(val answer: String, val cardID: String, val meanings: Set<String> = emptySet()) {
        constructor(card: Card) : this(ReviewQuestion.asciiUpper(card.word), card.id, Card.normalizedMeanings(card.tr))
    }

    fun generate(id: String, seeds: List<Word>, fillers: List<Word>, seed: ULong): Crossword? {
        val rng = SeededGenerator(seed)
        val usableSeeds = seeds.filter { it.answer.length in 2..MAX_SIZE }.take(4)
        val usableFillers = fillers.filter { it.answer.length in 3..MAX_SIZE }
        var seedCounts = mutableListOf(usableSeeds.size)
        for (fallback in listOf(3, 2)) if (fallback < usableSeeds.size) seedCounts += fallback
        if (usableSeeds.isEmpty()) seedCounts = mutableListOf(0)
        for (count in seedCounts) {
            val chosen = usableSeeds.take(count)
            repeat(ATTEMPTS) {
                attempt(id, chosen, usableFillers, rng)?.let { return it }
            }
        }
        return null
    }

    internal fun attempt(id: String, seeds: List<Word>, fillers: List<Word>, rng: SeededGenerator): Crossword? {
        val board = Board(MAX_SIZE)
        val seedOrder = seeds.shuffledWith(rng).sortedByDescending { it.answer.length }
        val placedIDs = mutableSetOf<String>()
        val placedAnswers = mutableSetOf<String>()
        val placedMeanings = mutableSetOf<String>()

        val first = seedOrder.firstOrNull() ?: fillers.randomElementWith(rng) ?: return null
        val startRow = rng.intIn(3..6)
        val startCol = rng.intIn(0..(MAX_SIZE - first.answer.length))
        board.place(first, startRow, startCol, CrosswordDirection.ACROSS)
        placedIDs += first.cardID
        placedAnswers += first.answer
        placedMeanings += first.meanings

        val pending = mutableListOf<Word>()
        for (seed in seedOrder.drop(1)) {
            val taken = placedMeanings + pending.flatMap { it.meanings }
            if (seed.meanings.none { it in taken }) pending += seed
        }

        fun placePending() {
            var progress = true
            while (progress) {
                progress = false
                for ((i, word) in pending.withIndex()) {
                    val spot = board.bestPlacement(word, rng) ?: continue
                    board.place(word, spot.row, spot.col, spot.direction)
                    placedIDs += word.cardID
                    placedAnswers += word.answer
                    placedMeanings += word.meanings
                    pending.removeAt(i)
                    progress = true
                    break
                }
            }
        }
        placePending()

        for (word in fillers.shuffledWith(rng)) {
            if (pending.isEmpty() && board.placed.size >= TARGET_WORDS) break
            if (board.placed.size >= MAX_WORDS) break
            if (word.cardID in placedIDs || word.answer in placedAnswers) continue
            if (word.meanings.any { it in placedMeanings }) continue
            val pendingMeanings = pending.flatMap { it.meanings }.toSet()
            if (word.meanings.any { it in pendingMeanings }) continue
            val spot = board.bestPlacement(word, rng) ?: continue
            board.place(word, spot.row, spot.col, spot.direction)
            placedIDs += word.cardID
            placedAnswers += word.answer
            placedMeanings += word.meanings
            placePending()
        }
        if (pending.isNotEmpty()) return null
        if (board.placed.size < MIN_WORDS) return null
        return board.crossword(id)
    }

    internal data class Placement(val row: Int, val col: Int, val direction: CrosswordDirection, val crossings: Int)

    internal data class Placed(val word: Word, val row: Int, val col: Int, val direction: CrosswordDirection)

    internal class Board(val size: Int) {
        private val cells = arrayOfNulls<Char>(size * size)
        private val owners = Array(size * size) { mutableListOf<CrosswordDirection>() }
        val placed = mutableListOf<Placed>()

        fun letter(r: Int, c: Int): Char? = if (r < 0 || c < 0 || r >= size || c >= size) null else cells[r * size + c]

        fun place(word: Word, row: Int, col: Int, direction: CrosswordDirection) {
            word.answer.forEachIndexed { i, ch ->
                val (r, c) = if (direction == CrosswordDirection.ACROSS) row to col + i else row + i to col
                cells[r * size + c] = ch
                owners[r * size + c].add(direction)
            }
            placed += Placed(word, row, col, direction)
        }

        /** Number of crossings if [word] fits at (row, col), else null. */
        fun check(word: Word, row: Int, col: Int, direction: CrosswordDirection): Int? {
            val letters = word.answer
            val (dr, dc) = if (direction == CrosswordDirection.ACROSS) 0 to 1 else 1 to 0
            val endR = row + dr * (letters.length - 1)
            val endC = col + dc * (letters.length - 1)
            if (row < 0 || col < 0 || endR >= size || endC >= size) return null
            if (letter(row - dr, col - dc) != null || letter(endR + dr, endC + dc) != null) return null
            var crossings = 0
            for ((i, ch) in letters.withIndex()) {
                val r = row + dr * i
                val c = col + dc * i
                val existing = letter(r, c)
                if (existing != null) {
                    if (existing != ch || direction in owners[r * size + c]) return null
                    crossings += 1
                } else if (letter(r - dc, c - dr) != null || letter(r + dc, c + dr) != null) {
                    return null
                }
            }
            return if (crossings > 0 && crossings < letters.length) crossings else null
        }

        /** A random placement among those with the most crossings. */
        fun bestPlacement(word: Word, rng: SeededGenerator): Placement? {
            val options = mutableListOf<Placement>()
            for (r in 0 until size) for (c in 0 until size) {
                val existing = letter(r, c) ?: continue
                word.answer.forEachIndexed { i, ch ->
                    if (ch != existing) return@forEachIndexed
                    check(word, r, c - i, CrosswordDirection.ACROSS)?.let { options += Placement(r, c - i, CrosswordDirection.ACROSS, it) }
                    check(word, r - i, c, CrosswordDirection.DOWN)?.let { options += Placement(r - i, c, CrosswordDirection.DOWN, it) }
                }
            }
            val most = options.maxOfOrNull { it.crossings } ?: return null
            return options.filter { it.crossings == most }.randomElementWith(rng)
        }

        /** Crops to the used area and numbers entries in reading order. */
        fun crossword(id: String): Crossword {
            var minR = size; var minC = size; var maxR = 0; var maxC = 0
            for (r in 0 until size) for (c in 0 until size) if (letter(r, c) != null) {
                minR = minOf(minR, r); minC = minOf(minC, c); maxR = maxOf(maxR, r); maxC = maxOf(maxC, c)
            }
            val starts = placed.map { GridPoint(it.row - minR, it.col - minC) }.toSet().sorted()
            val numberOf = starts.withIndex().associate { (i, p) -> p to i + 1 }
            val entries = placed.map { item ->
                val start = GridPoint(item.row - minR, item.col - minC)
                CrosswordEntry(numberOf.getValue(start), item.direction, start.row, start.col, item.word.answer, item.word.cardID)
            }
            return Crossword(id, maxC - minC + 1, maxR - minR + 1, entries)
        }
    }
}
