package com.enesseval.kilitkelime.core.games

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.RandomSource
import com.enesseval.kilitkelime.core.learning.intUntil
import com.enesseval.kilitkelime.core.learning.shuffledWith
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.review.ReviewQuestion

/** The 1.1 games. See docs/ANDROID_NOTES.md: built from the prompt, `V1_1_PLAN.md` was missing. */
enum class Game(val raw: String, val title: String) {
    WORD_HUNT("wordHunt", "Kelime Avı"),
    MATCH("match", "Eşleştir"),
}

/** Words for a game round: struggling and shown words of the learner's sources first. */
object GameWords {
    fun pick(db: SqlDb, rng: RandomSource, count: Int, filter: (Card) -> Boolean = { true }): List<Card> {
        val prefs = Preferences.load(db)
        val candidates = CardQueries.candidates(prefs.entitledDecks, db)
        val struggling = candidates.filter { it.state == LearningState.STRUGGLING }.map { it.cardID }.shuffledWith(rng)
        val shown = candidates.filter { it.state != LearningState.STRUGGLING && it.lastShownAt != null }.map { it.cardID }.shuffledWith(rng)
        val rest = candidates.filter { it.state != LearningState.STRUGGLING && it.lastShownAt == null }.map { it.cardID }.shuffledWith(rng)
        val ordered = (struggling + shown + rest).distinct()
        val result = mutableListOf<Card>()
        val meanings = mutableSetOf<String>()
        val words = mutableSetOf<String>()
        for (chunk in ordered.chunked(60)) {
            val cards = CardQueries.cards(chunk, db).associateBy { it.id }
            for (id in chunk) {
                val card = cards[id] ?: continue
                if (!filter(card)) continue
                val norm = Card.normalizedMeanings(card.tr)
                if (norm.any { it in meanings } || card.word.lowercase() in words) continue
                result += card
                meanings += norm
                words += card.word.lowercase()
                if (result.size == count) return result
            }
        }
        return result
    }
}

/** A finished round, kept in `game_result`. */
object GameResults {
    fun record(game: Game, score: Int, total: Int, seconds: Int, clock: AppClock, db: SqlDb) {
        db.execute(
            "INSERT INTO game_result (game, day, score, total, seconds, finished_at) VALUES (?, ?, ?, ?, ?, ?)",
            listOf(game.raw, clock.today, score, total, seconds, clock.now),
        )
        LearningStore.markStudied(clock.today, db)
    }

    fun playedToday(game: Game, clock: AppClock, db: SqlDb): Int =
        db.int("SELECT COUNT(*) FROM game_result WHERE game = ? AND day = ?", listOf(game.raw, clock.today))
}

/**
 * Kelime Avı: a word search. An 8 × 8 grid hides up to 6 words across, down or diagonally
 * (always read forwards); the clues are the Turkish meanings.
 */
data class WordHunt(val size: Int, val letters: List<Char>, val words: List<Placed>) {
    data class Placed(val card: Card, val answer: String, val row: Int, val col: Int, val dRow: Int, val dCol: Int) {
        val cells: List<Pair<Int, Int>> get() = answer.indices.map { (row + dRow * it) to (col + dCol * it) }
    }

    fun letter(row: Int, col: Int): Char = letters[row * size + col]

    /** The word whose cells are exactly the straight line from [start] to [end], either way round. */
    fun match(start: Pair<Int, Int>, end: Pair<Int, Int>): Placed? = words.firstOrNull { w ->
        (w.cells.first() == start && w.cells.last() == end) || (w.cells.first() == end && w.cells.last() == start)
    }

    companion object {
        const val SIZE = 8
        const val WORDS = 6
        private val directions = listOf(0 to 1, 1 to 0, 1 to 1, -1 to 1)

        fun make(cards: List<Card>, rng: RandomSource, size: Int = SIZE, wordCount: Int = WORDS): WordHunt? {
            val grid = arrayOfNulls<Char>(size * size)
            val placed = mutableListOf<Placed>()
            val usable = cards.filter { it.isSingleWord && it.word.length in 3..size }
                .sortedByDescending { it.word.length }
            for (card in usable) {
                if (placed.size == wordCount) break
                val answer = ReviewQuestion.asciiUpper(card.word)
                val spots = mutableListOf<Placed>()
                for ((dr, dc) in directions) for (r in 0 until size) for (c in 0 until size) {
                    val endR = r + dr * (answer.length - 1)
                    val endC = c + dc * (answer.length - 1)
                    if (endR !in 0 until size || endC !in 0 until size) continue
                    val fits = answer.indices.all { i ->
                        val existing = grid[(r + dr * i) * size + (c + dc * i)]
                        existing == null || existing == answer[i]
                    }
                    if (fits) spots += Placed(card, answer, r, c, dr, dc)
                }
                if (spots.isEmpty()) continue
                val spot = spots[rng.intUntil(0, spots.size)]
                spot.cells.forEachIndexed { i, (r, c) -> grid[r * size + c] = answer[i] }
                placed += spot
            }
            if (placed.size < 3) return null
            val alphabet = "ABCDEFGHIJKLMNOPRSTUVYZ"
            val letters = grid.map { it ?: alphabet[rng.intUntil(0, alphabet.length)] }
            return WordHunt(size, letters, placed)
        }
    }
}

/** Eşleştir: English words and Turkish meanings in two shuffled columns. */
class MatchRound(val cards: List<Card>, rng: RandomSource) {
    val left: List<Card> = cards.shuffledWith(rng)
    val right: List<Card> = cards.shuffledWith(rng)
    private val matched = mutableSetOf<String>()
    private val missed = mutableSetOf<String>()

    val matchedIDs: Set<String> get() = matched
    val isFinished: Boolean get() = matched.size == cards.size
    /** Words paired right on the first try. */
    val score: Int get() = cards.count { it.id in matched && it.id !in missed }

    /** Pairs an English word with a meaning; a wrong pair marks the English word missed. */
    fun pair(wordID: String, meaningID: String): Boolean {
        if (wordID in matched) return false
        return if (wordID == meaningID) {
            matched += wordID
            true
        } else {
            missed += wordID
            false
        }
    }

    /** Records the round: first-try pairs count as correct answers, misses as wrong ones. */
    fun record(clock: AppClock, db: SqlDb, seconds: Int) = db.transaction {
        for (card in cards) {
            LearningStore.record(LearningEvent.Answered(card.id !in missed), card.id, ReviewSource.MATCH, clock, db)
        }
        GameResults.record(Game.MATCH, score, cards.size, seconds, clock, db)
    }

    companion object {
        const val SIZE = 6
    }
}
