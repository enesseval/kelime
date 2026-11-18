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
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
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
    /** At most this many cards of the last round may come again, and never among the first [FRESH_HEAD] questions. */
    const val MAX_REPEATS = 3
    const val FRESH_HEAD = 4

    private fun ids(db: SqlDb, key: SettingKey): List<String> =
        Settings.string(db, key)?.split(',')?.filter { it.isNotEmpty() } ?: emptyList()

    fun lastRound(db: SqlDb): List<String> = ids(db, SettingKey.REVIEW_LAST_ROUND)
    fun lastWrong(db: SqlDb): List<String> = ids(db, SettingKey.REVIEW_LAST_WRONG)

    /** The round's cards are remembered (it survives closing the app); nothing is wrong yet. */
    fun remember(db: SqlDb, questions: List<ReviewQuestion>) {
        Settings.set(db, SettingKey.REVIEW_LAST_ROUND, questions.joinToString(",") { it.id })
        Settings.set(db, SettingKey.REVIEW_LAST_WRONG, "")
    }

    /** A wrong answer in the round makes the card eligible to come back once in the next one. */
    fun noteAnswer(db: SqlDb, cardID: String, correct: Boolean) {
        if (correct) return
        val wrong = lastWrong(db)
        if (cardID in wrong || cardID !in lastRound(db)) return
        Settings.set(db, SettingKey.REVIEW_LAST_WRONG, (wrong + cardID).joinToString(","))
    }

    /** Builds a round and remembers it; the screen calls this inside one write. */
    fun start(db: SqlDb, rng: RandomSource, deck: DeckID? = null, today: LocalDate? = null): List<ReviewQuestion> =
        makeQuestions(db, rng, deck, today).also { if (it.isNotEmpty()) remember(db, it) }

    /**
     * The 10 ids of a round from [ordered] (best first). Cards of the last round are left out, except up
     * to [MAX_REPEATS] of the ones answered wrong; a small pool is filled up with the rest so the round is
     * not short. The round is then shuffled, the cards of the last round never among the first [FRESH_HEAD].
     */
    fun pickRound(ordered: List<String>, last: List<String>, lastWrong: List<String>, rng: RandomSource): List<String> {
        val lastSet = last.toSet()
        val picked = mutableListOf<String>()
        var repeats = 0
        val skipped = mutableListOf<String>()
        for (id in ordered) {
            if (picked.size >= QUESTION_COUNT) break
            if (id !in lastSet) { picked += id; continue }
            if (id in lastWrong && repeats < MAX_REPEATS) { picked += id; repeats++ } else skipped += id
        }
        // A pool too small for the rules: the last round's cards fill the gaps (wrong ones first).
        if (picked.size < QUESTION_COUNT) {
            for (id in skipped.sortedBy { if (it in lastWrong) 0 else 1 }) {
                if (picked.size >= QUESTION_COUNT) break
                picked += id
            }
        }
        val fresh = picked.filter { it !in lastSet }.shuffledWith(rng)
        val again = picked.filter { it in lastSet }
        val head = fresh.take(FRESH_HEAD)
        return head + (fresh.drop(FRESH_HEAD) + again).shuffledWith(rng)
    }

    /**
     * Up to 10 cards: struggling first, then learned words due for review (with [today]), then new
     * words the lock screen has shown, then other new words; learned words if the source runs short.
     */
    fun makeQuestions(db: SqlDb, rng: RandomSource, deck: DeckID? = null, today: LocalDate? = null): List<ReviewQuestion> {
        val ordered = orderedIds(db, rng, deck, today)
        val ids = pickRound(ordered, lastRound(db), lastWrong(db), rng)
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

    /** Every card of the source, best first: the priority above, equal days shuffled within a group. */
    fun orderedIds(db: SqlDb, rng: RandomSource, deck: DeckID? = null, today: LocalDate? = null): List<String> {
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
        // Within a group the day is all there is to sort by, so equal days are shuffled first (the sort is stable);
        // otherwise the same words came in the same order every round.
        fun byDay(group: List<Pair<String, String>>) = group.shuffledWith(rng).sortedBy { it.second }.map { it.first }
        return byDay(struggling) + byDay(due) + shownNew.shuffledWith(rng) + otherNew.shuffledWith(rng) + byDay(learned)
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
