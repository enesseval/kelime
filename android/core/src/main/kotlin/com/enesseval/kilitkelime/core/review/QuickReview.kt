package com.enesseval.kilitkelime.core.review

import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.query
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.RandomSource
import com.enesseval.kilitkelime.core.learning.SpacedReview
import com.enesseval.kilitkelime.core.learning.shuffledWith
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.Preferences
import java.time.LocalDate
import java.util.Locale
import java.util.UUID

/** One Quick Review question. */
data class ReviewQuestion(val card: Card, val kind: Kind) {
    sealed interface Kind {
        /** Turkish meaning → pick the English word from 4 options. */
        data class Meaning(val options: List<String>) : Kind
        /** Turkish meaning + sentence with a blank → type the word; first letter given. */
        data object Write : Kind
    }

    val id: String get() = card.id

    val kicker: String get() = if (kind is Kind.Write) "KELİMEYİ YAZ" else "BU KELİMENİN İNGİLİZCESİ"

    /** The example sentence with the word replaced by a blank. */
    val blankedSentence: String
        get() {
            val sentence = card.exampleEN
            val index = sentence.indexOf(card.word, ignoreCase = true)
            if (index < 0) return sentence
            return sentence.substring(0, index) + "_".repeat(8) + sentence.substring(index + card.word.length)
        }

    /** Letters compare with ASCII uppercasing, never the device locale (Turkish "i" → "İ"). */
    fun isCorrect(answer: String): Boolean = asciiUpper(answer.trim()) == asciiUpper(card.word)

    /** What went wrong in a close typed answer, in Turkish; null when right, empty or not close. */
    fun mistakeHint(answer: String): String? {
        val typed = asciiUpper(answer.trim())
        val word = asciiUpper(card.word)
        if (typed.isEmpty() || typed == word || typed.length != word.length) return null
        val wrong = wrongPositions(answer, card.word)
        if (wrong.size == 2 && wrong[1] == wrong[0] + 1 && typed[wrong[0]] == word[wrong[1]] && typed[wrong[1]] == word[wrong[0]]) {
            return "Çok yakındın: ${wrong[0] + 1}. ve ${wrong[1] + 1}. harfin yeri karışmış."
        }
        if (wrong.size == 1) {
            val i = wrong[0]
            val got = typed[i].toString().lowercase(Locale.ROOT)
            val want = word[i].toString().lowercase(Locale.ROOT)
            return "Çok yakındın: yalnızca ${i + 1}. harf yanlış, \"$got\" değil \"$want\"."
        }
        if (wrong.size * 2 <= word.length) return "Yakındın: ${wrong.size} harf yanlış."
        return null
    }

    companion object {
        fun wrongPositions(answer: String, word: String): List<Int> {
            val typed = asciiUpper(answer.trim())
            val target = asciiUpper(word)
            return target.indices.filter { it >= typed.length || typed[it] != target[it] }
        }

        fun asciiUpper(text: String): String = text.uppercase(Locale.ROOT)
    }
}

/** Builds Quick Review sessions (port of `QuickReview.swift`). */
object QuickReview {
    const val QUESTION_COUNT = 10
    const val OPTION_COUNT = 4
    const val MAX_WRITE_LENGTH = 9

    /**
     * Up to 10 cards: struggling first, then learned words due for review (with [today]), then new
     * words the lock screen has shown, then other new words; learned words if the source runs short.
     */
    fun makeQuestions(db: SqlDb, rng: RandomSource, deck: DeckID? = null, today: LocalDate? = null): List<ReviewQuestion> {
        val prefs = Preferences.load(db)
        val filter = (if (deck != null) CardQueries.deckFilter(listOf(deck)) else CardQueries.sourceFilter(prefs.entitledDecks, db))
            ?: return emptyList()
        data class Row(val id: String, val state: LearningState, val shown: Int, val answered: String, val streak: Int)
        val rows = db.query(
            Sql(
                """SELECT c.id, COALESCE(s.state, 'new') AS state, COALESCE(s.times_shown, 0) AS shown,
                          s.last_answered_on AS answered, COALESCE(s.correct_streak, 0) AS streak
                   FROM card c LEFT JOIN card_state s ON s.card_id = c.id WHERE """,
            ) + filter,
        ) { Row(it.requireString("id"), LearningState.fromRaw(it.string("state")) ?: LearningState.NEW, it.int("shown") ?: 0, it.string("answered") ?: "", it.int("streak") ?: 0) }

        val struggling = mutableListOf<Pair<String, String>>()
        val due = mutableListOf<Pair<String, String>>()
        val shownNew = mutableListOf<String>()
        val otherNew = mutableListOf<String>()
        val learned = mutableListOf<Pair<String, String>>()
        for (row in rows) when (row.state) {
            LearningState.STRUGGLING -> struggling += row.id to row.answered
            LearningState.NEW -> if (row.shown > 0) shownNew += row.id else otherNew += row.id
            LearningState.LEARNED -> {
                val last = LocalDates.parse(row.answered)
                if (today != null && last != null && SpacedReview.isDue(CardState(row.id, LearningState.LEARNED, row.streak, lastAnsweredOn = last), today)) {
                    due += row.id to row.answered
                } else {
                    learned += row.id to row.answered
                }
            }
        }
        val ordered = struggling.sortedBy { it.second }.map { it.first } +
            due.sortedBy { it.second }.map { it.first } +
            shownNew.shuffledWith(rng) +
            otherNew.shuffledWith(rng) +
            learned.sortedBy { it.second }.map { it.first }
        val ids = ordered.take(QUESTION_COUNT)
        val cards = CardQueries.cards(ids, db).associateBy { it.id }

        val questions = mutableListOf<ReviewQuestion>()
        ids.forEachIndexed { index, id ->
            val card = cards[id] ?: return@forEachIndexed
            if (index % 3 == 1 && card.isSingleWord && card.word.length <= MAX_WRITE_LENGTH) {
                questions += ReviewQuestion(card, ReviewQuestion.Kind.Write)
            } else {
                questions += ReviewQuestion(card, ReviewQuestion.Kind.Meaning(CardQueries.quizOptions(card, OPTION_COUNT, db, rng)))
            }
        }
        return questions
    }
}

/** The running state of one session. Pure: answers are recorded through `LearningStore`. */
class ReviewSession(val questions: List<ReviewQuestion>, val id: String = UUID.randomUUID().toString()) {
    data class Result(val card: Card, val correct: Boolean, val before: LearningState, val after: LearningState)

    var index: Int = 0; private set
    private val _results = mutableListOf<Result>()
    val results: List<Result> get() = _results

    val current: ReviewQuestion? get() = questions.getOrNull(index)
    val isFinished: Boolean get() = index >= questions.size
    /** Answered the current question but not yet moved on. */
    val awaitingContinue: Boolean get() = _results.size > index
    val progress: Double get() = if (questions.isEmpty()) 1.0 else _results.size.toDouble() / questions.size

    fun record(correct: Boolean, before: LearningState, after: LearningState) {
        val question = current ?: return
        if (awaitingContinue) return
        _results += Result(question.card, correct, before, after)
    }

    fun advance() {
        if (awaitingContinue) index += 1
    }

    val score: Int get() = _results.count { it.correct }
    val newlyLearned: List<Card> get() = _results.filter { it.after == LearningState.LEARNED && it.before != LearningState.LEARNED }.map { it.card }
    val newlyStruggling: List<Card> get() = _results.filter { !it.correct && it.after == LearningState.STRUGGLING }.map { it.card }
}
