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

/** The 1.1 games (docs/V1_1_PLAN.md §2). */
enum class Game(val raw: String, val title: String, val signal: String, val source: StreakSource) {
    WORD_HUNT("wordHunt", "Kelime Avı", "game.wordsearch.finished", StreakSource.WORD_SEARCH),
    MATCH("match", "Eşleştir", "game.match.finished", StreakSource.MATCH),
}

/**
 * Words for a game round, from the learner's own sources (the lock screen's): struggling words
 * first, then new words the lock screen has shown, then learned words due for review; other words
 * of the sources fill up when those run short. No two picked words share a Turkish meaning.
 */
object GameWords {
    fun pick(db: SqlDb, rng: RandomSource, count: Int, today: java.time.LocalDate? = null, filter: (Card) -> Boolean = { true }): List<Card> {
        val prefs = Preferences.load(db)
        val candidates = CardQueries.candidates(prefs.entitledDecks, db, today)
        fun ids(p: (com.enesseval.kilitkelime.core.learning.SchedulerCandidate) -> Boolean) = candidates.filter(p).map { it.cardID }.shuffledWith(rng)
        val struggling = ids { it.state == LearningState.STRUGGLING }
        val shownNew = ids { it.state == LearningState.NEW && it.lastShownAt != null }
        val due = ids { it.state == LearningState.LEARNED && it.due }
        val rest = ids { !(it.state == LearningState.STRUGGLING || (it.state == LearningState.NEW && it.lastShownAt != null) || (it.state == LearningState.LEARNED && it.due)) }
        val ordered = (struggling + shownNew + due + rest).distinct()
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

/**
 * The free, unlimited games in the order the puzzle's result screen suggests them (docs/V1_2_PLAN.md §3):
 * Kelime Avı, Eşleştir, then the new ones. The next one is the first not played today.
 */
object FreeGames {
    val order = listOf(Game.WORD_HUNT, Game.MATCH)

    fun next(db: SqlDb, clock: AppClock): Game =
        order.firstOrNull { GameResults.playedToday(it, clock, db) == 0 } ?: order.first()
}

/** Finished rounds (`game_result`); finishing a game counts the day for the streak. */
object GameResults {
    /** Records the round; returns true when it newly counted today for the streak. */
    fun record(game: Game, score: Int, total: Int, seconds: Int, clock: AppClock, db: SqlDb): Boolean {
        db.execute(
            "INSERT INTO game_result (game, day, score, total, seconds, finished_at) VALUES (?, ?, ?, ?, ?, ?)",
            listOf(game.raw, clock.today, score, total, seconds, clock.now),
        )
        return LearningStore.markStudied(clock.today, game.source, db)
    }

    fun playedToday(game: Game, clock: AppClock, db: SqlDb): Int =
        db.int("SELECT COUNT(*) FROM game_result WHERE game = ? AND day = ?", listOf(game.raw, clock.today))

    fun best(game: Game, db: SqlDb): Int = db.int("SELECT COALESCE(MAX(score), 0) FROM game_result WHERE game = ?", listOf(game.raw))
}

/**
 * Kelime Avı: a word search. A 10 × 10 grid (9 × 9 on small screens) hides up to 6 words of 3 to
 * (size − 1) plain letters across, down or diagonally, always read forwards (docs/SYNC.md). The clues are the Turkish
 * meanings. Deterministic for a seeded [RandomSource].
 */
data class WordHunt(val size: Int, val letters: List<Char>, val words: List<Placed>) {
    data class Placed(val card: Card, val answer: String, val row: Int, val col: Int, val dRow: Int, val dCol: Int) {
        val cells: List<Pair<Int, Int>> get() = answer.indices.map { (row + dRow * it) to (col + dCol * it) }
        /** "İlk harfi göster" highlights this cell. */
        val firstCell: Pair<Int, Int> get() = row to col
    }

    fun letter(row: Int, col: Int): Char = letters[row * size + col]

    /** The word whose cells are exactly the line from [start] to [end], either way round. */
    fun match(start: Pair<Int, Int>, end: Pair<Int, Int>): Placed? = words.firstOrNull { w ->
        (w.cells.first() == start && w.cells.last() == end) || (w.cells.first() == end && w.cells.last() == start)
    }

    /**
     * The word a dragged line spells (as iOS `placement(spelledBy:)`): its own placement, or another
     * line that happens to spell a hidden word in either direction (filler letters can repeat one).
     * Words in [skip] (already found) are left out.
     */
    fun spelled(cells: List<Pair<Int, Int>>, skip: Set<String> = emptySet()): Placed? {
        if (cells.size < 2) return null
        match(cells.first(), cells.last())?.takeIf { it.card.id !in skip && it.cells.size == cells.size }?.let { return it }
        val forward = cells.joinToString("") { (r, c) -> letter(r, c).toString() }
        val backward = forward.reversed()
        return words.firstOrNull { it.card.id !in skip && (it.answer == forward || it.answer == backward) }
    }

    /** What a finished round teaches: hinted words were already recorded as hints. */
    fun record(found: Set<String>, hinted: Set<String>, seconds: Int, clock: AppClock, db: SqlDb): Boolean = db.transaction {
        for (w in words) if (w.card.id in found && w.card.id !in hinted) {
            LearningStore.record(LearningEvent.Answered(true), w.card.id, ReviewSource.WORD_HUNT, clock, db)
        }
        GameResults.record(Game.WORD_HUNT, found.size, words.size, seconds, clock, db)
    }

    companion object {
        const val SIZE = 10
        const val SMALL_SIZE = 9
        const val WORDS = 6
        const val MIN_LENGTH = 3
        private val directions = listOf(0 to 1, 1 to 0, 1 to 1)

        /** Words of 3 to (size − 1) letters: up to 9 on 10 × 10, 8 on 9 × 9. */
        fun maxLength(size: Int) = size - 1

        fun usable(card: Card, size: Int = SIZE) = card.isSingleWord && card.word.length in MIN_LENGTH..maxLength(size)

        fun make(cards: List<Card>, rng: RandomSource, size: Int = SIZE, wordCount: Int = WORDS): WordHunt? {
            val grid = arrayOfNulls<Char>(size * size)
            val placed = mutableListOf<Placed>()
            for (card in cards.filter { usable(it, size) }.sortedByDescending { it.word.length }) {
                if (placed.size == wordCount) break
                val answer = ReviewQuestion.asciiUpper(card.word)
                val spots = mutableListOf<Placed>()
                for ((dr, dc) in directions) for (r in 0 until size) for (c in 0 until size) {
                    val endR = r + dr * (answer.length - 1)
                    val endC = c + dc * (answer.length - 1)
                    if (endR >= size || endC >= size) continue
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
            // All 26 letters: a missing one (Q, W, X) would give away any word that contains it.
            val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            return WordHunt(size, grid.map { it ?: alphabet[rng.intUntil(0, alphabet.length)] }, placed)
        }
    }
}

/**
 * Eşleştir (docs/SYNC.md, 2026-11-02): a 60-second round. Five English words on the left, five
 * Turkish meanings on the right, the two columns shuffled apart so no card starts with both halves
 * on one row. A matched pair leaves its places empty; once three places per side are empty (or the
 * board is), the next three cards are dealt into them at random, again never with a card's halves
 * on one row. Port of `MatchGame.swift`.
 */
class MatchGame(cards: List<Card>, private val rng: RandomSource, val boardSize: Int = BOARD) {
    private val queue = ArrayDeque(cards.drop(boardSize))
    /** Left column: English words; right column: meanings. Null = an empty place. */
    val left: MutableList<Card?>
    val right: MutableList<Card?>
    private val matched = mutableListOf<String>()
    private val missed = mutableListOf<String>()
    private val firstTryIDs = mutableListOf<String>()

    init {
        val board = cards.take(boardSize)
        left = board.shuffledWith(rng).toMutableList<Card?>()
        right = board.shuffledWith(rng).toMutableList<Card?>()
        if (right.size > 1) {
            for (i in right.indices) if (right[i]?.id == left[i]?.id) swap(right, i, (i + 1) % right.size)
            for (i in right.indices) if (right[i]?.id == left[i]?.id) swap(right, i, (i + right.size - 1) % right.size)
        }
    }

    private fun swap(list: MutableList<Card?>, a: Int, b: Int) {
        val t = list[a]; list[a] = list[b]; list[b] = t
    }

    val score: Int get() = matched.size
    val matchedIDs: Set<String> get() = matched.toSet()
    val missedIDs: Set<String> get() = missed.toSet()
    /** Cards matched right on the first try, in order. */
    val firstTry: List<String> get() = firstTryIDs
    private val byID = cards.associateBy { it.id }
    /** The words paired right on the first try, for the result and the share card (iOS `firstTry`). */
    val firstTryCards: List<Card> get() = firstTryIDs.mapNotNull { byID[it] }
    /** The words mixed up at least once (iOS `missed`). */
    val missedCards: List<Card> get() = missed.distinct().mapNotNull { byID[it] }
    val isEmpty: Boolean get() = left.all { it == null } && right.all { it == null }

    /** Whether the word at [leftIndex] and the meaning at [rightIndex] match, without playing them. */
    fun isMatch(leftIndex: Int, rightIndex: Int): Boolean {
        val en = left.getOrNull(leftIndex) ?: return false
        val tr = right.getOrNull(rightIndex) ?: return false
        return en.id == tr.id || Card.normalizedMeanings(en.tr) == Card.normalizedMeanings(tr.tr)
    }

    /**
     * Pairs the word at [leftIndex] with the meaning at [rightIndex]; true when right. Two cards
     * sharing a meaning count as a match too; their other halves then match each other.
     */
    fun pair(leftIndex: Int, rightIndex: Int): Boolean {
        val en = left.getOrNull(leftIndex) ?: return false
        if (right.getOrNull(rightIndex) == null) return false
        if (isMatch(leftIndex, rightIndex)) {
            matched += en.id
            if (en.id !in missed) firstTryIDs += en.id
            left[leftIndex] = null
            right[rightIndex] = null
            refill()
            return true
        }
        if (en.id !in missed) missed += en.id
        return false
    }

    /** Deals the next cards once [REFILL_AT] places per side (or the whole board) are empty. */
    private fun refill() {
        val emptyLeft = left.indices.filter { left[it] == null }
        val emptyRight = right.indices.filter { right[it] == null }
        val boardEmpty = emptyLeft.size == left.size
        if (!(emptyLeft.size >= REFILL_AT || boardEmpty) || queue.isEmpty()) return
        val count = minOf(emptyLeft.size, emptyRight.size, queue.size)
        val dealt = (0 until count).map { queue.removeFirst() }
        var leftSlots = emptyLeft.shuffledWith(rng)
        var rightSlots = emptyRight.shuffledWith(rng)
        var tries = 0
        while (tries < 20 && (0 until count).any { leftSlots[it] == rightSlots[it] }) {
            leftSlots = leftSlots.shuffledWith(rng)
            rightSlots = rightSlots.shuffledWith(rng)
            tries++
        }
        dealt.forEachIndexed { i, card ->
            left[leftSlots[i]] = card
            right[rightSlots[i]] = card
        }
    }

    /** Missed words become struggling (once); first-try matches count as correct. */
    fun record(seconds: Int, clock: AppClock, db: SqlDb): Boolean = db.transaction {
        for (id in missed) LearningStore.record(LearningEvent.Answered(false), id, ReviewSource.MATCH, clock, db)
        for (id in firstTryIDs) LearningStore.record(LearningEvent.Answered(true), id, ReviewSource.MATCH, clock, db)
        GameResults.record(Game.MATCH, score, (matched + missed).toSet().size, seconds, clock, db)
    }

    companion object {
        const val BOARD = 5
        /** Empty places per side that bring the next cards in. */
        const val REFILL_AT = 3
        const val SECONDS = 60
        /** Enough words for a fast player in 60 seconds. */
        const val POOL = 40
    }
}
