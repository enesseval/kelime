package com.enesseval.kilitkelime.core.games

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.RandomSource
import com.enesseval.kilitkelime.core.learning.intUntil
import com.enesseval.kilitkelime.core.learning.shuffledWith
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.ReviewSource

/**
 * Cümle Kur (docs/V1_2_PLAN.md §4a): the Turkish sentence on top, the English sentence's words as
 * shuffled cards below; the learner taps them into order. Round of 5 sentences, two tries each.
 */
object SentenceTokens {
    const val MIN_WORDS = 4
    const val MAX_WORDS = 10

    /**
     * The English sentence's words in order, as the cards show them: punctuation stays on the word it
     * follows (the last one, normally), and only the first word loses its capital ("I" and acronyms keep
     * theirs), so the cards do not give the start away. Null when the card has no usable sentence
     * (4 to 10 words, a Turkish translation, at least two different words so a shuffle can differ).
     */
    fun tokens(card: Card): List<String>? {
        if (card.exampleTR.isBlank()) return null
        val words = card.exampleEN.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (words.size !in MIN_WORDS..MAX_WORDS) return null
        val tokens = words.mapIndexed { i, w -> if (i == 0) lowerFirst(w) else w }
        if (tokens.distinct().size < 2) return null
        return tokens
    }

    fun usable(card: Card): Boolean = tokens(card) != null

    private fun lowerFirst(word: String): String {
        val first = word.first()
        if (!first.isUpperCase()) return word
        // "I", "I'm", "I'll": the pronoun is always capital.
        if (first == 'I' && (word.length == 1 || !word[1].isLetter())) return word
        // Only a word whose rest is lowercase loses its first capital: TV, DNA, McDonald's stay as written.
        if (word.substring(1).any { it.isUpperCase() }) return word
        return first.lowercaseChar() + word.substring(1)
    }

    /** What a card shows in row [position]: only the first place is capitalised. */
    fun shown(token: String, position: Int): String =
        if (position == 0 && token.first().isLowerCase()) token.first().uppercaseChar() + token.substring(1) else token

    /** The finished sentence as written: first word capital, the rest as is. */
    fun sentence(tokens: List<String>): String = tokens.mapIndexed { i, t -> shown(t, i) }.joinToString(" ")

    /**
     * A shuffled order of the word indices that never spells the right sentence (compared as texts,
     * since two cards may show the same word).
     */
    fun shuffledOrder(tokens: List<String>, rng: RandomSource): List<Int> {
        val indices = tokens.indices.toList()
        fun spells(order: List<Int>) = order.map { tokens[it] } == tokens
        repeat(40) {
            val order = indices.shuffledWith(rng)
            if (!spells(order)) return order
        }
        // Certain fallback: swap two places that show different words.
        val i = tokens.indices.first { tokens[it] != tokens[0] }.let { 0 to it }
        return indices.toMutableList().also { it[i.first] = i.second; it[i.second] = i.first }
    }
}

/** What "Kontrol et" found. */
sealed class SentenceCheck {
    object Correct : SentenceCheck()
    /** A second try is left; the cards in these row places are in the wrong place. */
    data class Wrong(val wrongPlaces: Set<Int>) : SentenceCheck()
    /** The second try failed: the right sentence is shown. */
    object Revealed : SentenceCheck()
}

class SentenceGame(cards: List<Card>, private val rng: RandomSource, val count: Int = ROUND) {
    class Item(val card: Card, val tokens: List<String>, val tileOrder: List<Int>) {
        /** Text of tile [tile] (an index into [tileOrder]). */
        fun tileText(tile: Int): String = tokens[tileOrder[tile]]
    }

    /** Two cards sharing one example sentence never meet in a round. */
    val items: List<Item> = cards.distinctBy { it.exampleEN.trim().lowercase() }.mapNotNull { card ->
        val tokens = SentenceTokens.tokens(card) ?: return@mapNotNull null
        Item(card, tokens, SentenceTokens.shuffledOrder(tokens, rng))
    }.take(count)

    var index = 0
        private set
    /** Tiles in the row, in row order. */
    val row = mutableListOf<Int>()
    var tries = 0
        private set
    var revealed = false
        private set
    var solved = false
        private set

    private val firstTry = mutableListOf<String>()
    private val failed = mutableListOf<String>()

    val current: Item? get() = items.getOrNull(index)
    val isFinished: Boolean get() = index >= items.size
    val firstTryCount: Int get() = firstTry.size
    val firstTryCards: List<Card> get() = items.map { it.card }.filter { it.id in firstTry }
    val failedCards: List<Card> get() = items.map { it.card }.filter { it.id in failed }

    /** Whether tile [tile] is in the row. */
    fun placed(tile: Int) = tile in row

    /** Tap a tile below: it moves to the end of the row. */
    fun place(tile: Int) {
        val item = current ?: return
        if (solved || revealed || tile !in item.tokens.indices || placed(tile)) return
        row += tile
    }

    /** Tap a card in the row: it goes back below. */
    fun remove(rowPlace: Int) {
        if (solved || revealed || rowPlace !in row.indices) return
        row.removeAt(rowPlace)
    }

    val canCheck: Boolean get() = current?.let { row.size == it.tokens.size } == true && !solved && !revealed

    fun check(): SentenceCheck? {
        val item = current ?: return null
        if (!canCheck) return null
        tries++
        val wrong = row.indices.filter { item.tileText(row[it]) != item.tokens[it] }.toSet()
        if (wrong.isEmpty()) {
            solved = true
            if (tries == 1) firstTry += item.card.id else failed += item.card.id
            return SentenceCheck.Correct
        }
        if (tries >= MAX_TRIES) {
            revealed = true
            failed += item.card.id
            return SentenceCheck.Revealed
        }
        return SentenceCheck.Wrong(wrong)
    }

    /** The next sentence (after a right answer or a shown one). */
    fun next() {
        if (!solved && !revealed) return
        index++
        row.clear(); tries = 0; solved = false; revealed = false
    }

    /** First try right: correct; wrong or shown: not correct. The round counts the day for the streak. */
    fun record(seconds: Int, clock: AppClock, db: SqlDb): Boolean = db.transaction {
        if (firstTry.isEmpty() && failed.isEmpty()) return@transaction false
        for (item in items) {
            val id = item.card.id
            if (id in firstTry) LearningStore.record(LearningEvent.Answered(true), id, ReviewSource.SENTENCE, clock, db)
            else if (id in failed) LearningStore.record(LearningEvent.Answered(false), id, ReviewSource.SENTENCE, clock, db)
        }
        GameResults.record(Game.SENTENCE, firstTry.size, items.size, seconds, clock, db)
    }

    companion object {
        const val ROUND = 5
        const val MAX_TRIES = 2
        /** Cards to draw so enough have a usable sentence. */
        const val POOL = 12
    }
}

/**
 * Boşluğu Doldur (docs/V1_2_PLAN.md §4b): the English sentence with the card's word blanked out, its
 * Turkish translation small underneath, four choices: the word and three of the same part of speech
 * and level. A card whose word does not appear in its sentence as written (thought / think) is left out.
 */
object GapFill {
    const val BLANK = "_____"
    const val OPTIONS = 4

    class Question(val card: Card, val sentence: String, val translation: String, val options: List<String>, val answerIndex: Int) {
        val answer: String get() = options[answerIndex]
    }

    private fun pattern(word: String) =
        Regex("(?<![\\p{L}'’])" + Regex.escape(word) + "(?![\\p{L}'’])", RegexOption.IGNORE_CASE)

    /** The sentence with every occurrence of the word blanked, or null when it does not occur as written. */
    fun blanked(card: Card): String? {
        if (card.word.isBlank() || card.exampleEN.isBlank()) return null
        val re = pattern(card.word)
        if (!re.containsMatchIn(card.exampleEN)) return null
        return re.replace(card.exampleEN, BLANK)
    }

    fun usable(card: Card): Boolean = blanked(card) != null

    /** Cards that could be this card's wrong choices: same part of speech and level, other words. */
    fun distractorPool(card: Card, db: SqlDb): List<Card> =
        db.query(
            "SELECT * FROM card WHERE pos = ? AND level = ? AND id <> ? AND id NOT LIKE 'user-%'",
            listOf(card.pos.raw, card.level.raw, card.id), Card::from,
        )

    /** One question; null when the card is not usable or the pool has fewer than three suitable words. */
    fun question(card: Card, pool: List<Card>, rng: RandomSource): Question? {
        val blanked = blanked(card) ?: return null
        val sentenceLower = card.exampleEN.lowercase()
        val taken = mutableSetOf(card.word.lowercase())
        val wrong = mutableListOf<String>()
        for (candidate in pool.shuffledWith(rng)) {
            val w = candidate.word
            val key = w.lowercase()
            if (key in taken || candidate.pos != card.pos || candidate.level != card.level) continue
            // A choice already visible in the sentence would be an odd one out.
            if (pattern(w).containsMatchIn(sentenceLower)) continue
            taken += key
            wrong += w
            if (wrong.size == OPTIONS - 1) break
        }
        if (wrong.size < OPTIONS - 1) return null
        val options = (wrong + card.word).shuffledWith(rng)
        return Question(card, blanked, card.exampleTR, options, options.indexOf(card.word))
    }

    fun questions(db: SqlDb, cards: List<Card>, rng: RandomSource): List<Question> {
        val pools = mutableMapOf<Pair<String, String>, List<Card>>()
        return cards.mapNotNull { card ->
            if (!usable(card)) return@mapNotNull null
            val pool = pools.getOrPut(card.pos.raw to card.level.raw) { distractorPool(card, db) }
            question(card, pool, rng)
        }
    }
}

/** A 60-second round of [GapFill] questions, like Eşleştir: right goes green, wrong shows the answer. */
class GapFillGame(val questions: List<GapFill.Question>) {
    var index = 0
        private set
    var score = 0
        private set
    private val results = mutableListOf<Pair<String, Boolean>>()

    val current: GapFill.Question? get() = questions.getOrNull(index)
    val answered: Int get() = results.size
    val isEmpty: Boolean get() = index >= questions.size
    val missedCards: List<Card> get() = questions.map { it.card }.filter { c -> results.any { it.first == c.id && !it.second } }

    /** Right or not for the choice [option] of the current question; it counts once. */
    fun answer(option: Int): Boolean {
        val q = current ?: return false
        if (results.any { it.first == q.card.id }) return false
        val right = option == q.answerIndex
        results += q.card.id to right
        if (right) score++
        return right
    }

    /** The next question (the caller waits 1 s after a wrong answer). */
    fun next() { if (index < questions.size) index++ }

    /** Each answered word: correct or not; the round counts the day for the streak. */
    fun record(seconds: Int, clock: AppClock, db: SqlDb): Boolean = db.transaction {
        if (results.isEmpty()) return@transaction false
        for ((id, right) in results) LearningStore.record(LearningEvent.Answered(right), id, ReviewSource.GAP_FILL, clock, db)
        GameResults.record(Game.GAP_FILL, score, results.size, seconds, clock, db)
    }

    companion object {
        const val SECONDS = 60
        /** Enough questions for a fast player in 60 seconds. */
        const val POOL = 40
    }
}
