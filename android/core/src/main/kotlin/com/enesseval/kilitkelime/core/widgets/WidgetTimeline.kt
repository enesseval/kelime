package com.enesseval.kilitkelime.core.widgets

import com.enesseval.kilitkelime.core.crossword.DailyPuzzleSummary
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.dates.startInstant
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.RandomSource
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.model.RotationInterval
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.core.model.WidgetThemeID
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

/** Everything a widget, the wallpaper or the notification needs to render one moment. */
data class WidgetSnapshot(
    val date: Instant,
    val slotStart: Instant = date,
    /** null: no content yet. */
    val card: Card?,
    val state: LearningState = LearningState.NEW,
    val mode: WidgetMode = WidgetMode.CARD,
    val phase: Phase = Phase.ANSWER,
    val quizOptions: List<String> = emptyList(),
    val quizAnswer: String? = null,
    val reviewedToday: Int = 0,
    val dailyTarget: Int = WidgetTimelineBuilder.DAILY_TARGET,
    val struggling: List<Card> = emptyList(),
    val puzzleProgress: PuzzleCount? = null,
    val theme: WidgetThemeID = WidgetThemeID.PAPER,
    /**
     * Android self-test: the word of the previous slot, whose answer the lock-screen wallpaper
     * shows under the new question (a wallpaper cannot change halfway through a slot cheaply).
     */
    val previousCard: Card? = null,
) {
    /** Self-test shows the question first, then the answer. */
    enum class Phase { QUESTION, ANSWER }

    data class PuzzleCount(val solved: Int, val total: Int, val cells: Map<Int, Boolean> = emptyMap())

    val isEmpty: Boolean get() = card == null

    /** Quiz result: null until answered. */
    val quizCorrect: Boolean? get() = quizAnswer?.let { a -> card?.let { a == it.word } }

    companion object {
        fun empty(at: Instant) = WidgetSnapshot(date = at, card = null)
    }
}

/** Turns `widget_queue` into snapshots (port of `WidgetTimelineBuilder.swift`). */
object WidgetTimelineBuilder {
    const val DAILY_TARGET = 10
    val maxRevealDelay: Duration = Duration.ofMinutes(30)
    /** How long the quiz widget shows a result before the next question. */
    val quizResultDuration: Duration = Duration.ofSeconds(60)

    fun revealDelay(interval: RotationInterval): Duration = minOf(Duration.ofSeconds(interval.seconds / 2), maxRevealDelay)

    /** Snapshots from the current slot onward. Refills the queue first, so this writes. */
    fun build(db: SqlDb, clock: AppClock, rng: RandomSource, mode: WidgetMode? = null): List<WidgetSnapshot> {
        val now = clock.now
        val zone = clock.zone
        val prefs = Preferences.load(db)
        val resolvedMode = mode ?: prefs.defaultWidgetMode
        val queue = WidgetQueue.refill(db, clock, rng)
        if (queue.isEmpty()) return listOf(WidgetSnapshot.empty(now))

        val ids = queue.map { it.cardID }.toSet()
        val cards = CardQueries.cards(ids, db).associateBy { it.id }
        val states = ids.mapNotNull { CardState.fetch(db, it) }.associate { it.cardID to it.state }
        val struggling = strugglingCards(db, 3)
        val puzzle = DailyPuzzleSummary.load(db)
        val reviewsByDay = HashMap<LocalDate, Int>()
        fun reviews(at: Instant): Int {
            val day = LocalDates.of(at, zone)
            return reviewsByDay.getOrPut(day) { reviewCount(day, db) }
        }
        val previous = WidgetQueue.previous(queue.first().slotStart, db)?.let { CardQueries.card(it.cardID, db) }

        val delay = revealDelay(prefs.effectiveRotation)
        val snapshots = mutableListOf<WidgetSnapshot>()
        var lastCard = previous
        for (entry in queue) {
            val card = cards[entry.cardID] ?: continue
            val cardMode = if (card.exampleEN.isEmpty() && (resolvedMode == WidgetMode.SENTENCE || resolvedMode == WidgetMode.WORD_AND_SENTENCE)) {
                WidgetMode.CARD
            } else resolvedMode
            val base = WidgetSnapshot(
                date = entry.slotStart,
                slotStart = entry.slotStart,
                card = card,
                state = states[card.id] ?: LearningState.NEW,
                mode = cardMode,
                phase = if (cardMode == WidgetMode.SELF_TEST) WidgetSnapshot.Phase.QUESTION else WidgetSnapshot.Phase.ANSWER,
                quizOptions = entry.quizOptions,
                quizAnswer = entry.quizAnswer,
                reviewedToday = reviews(entry.slotStart),
                struggling = struggling,
                puzzleProgress = puzzle?.takeIf { it.day == LocalDates.of(entry.slotStart, zone) }
                    ?.let { WidgetSnapshot.PuzzleCount(it.solved, it.total, it.cells) },
                theme = prefs.effectiveTheme,
                previousCard = lastCard,
            )
            snapshots += base
            if (resolvedMode == WidgetMode.SELF_TEST) {
                val at = entry.slotStart.plus(delay)
                snapshots += base.copy(date = at, phase = WidgetSnapshot.Phase.ANSWER, reviewedToday = reviews(at))
            }
            lastCard = card
        }
        return snapshots.ifEmpty { listOf(WidgetSnapshot.empty(now)) }
    }

    /** The snapshot on screen now (the latest one that has started). */
    fun current(db: SqlDb, clock: AppClock, rng: RandomSource, mode: WidgetMode? = null): WidgetSnapshot {
        val all = build(db, clock, rng, mode)
        return all.lastOrNull { it.date <= clock.now } ?: all.first()
    }

    /** The quiz widget: the first unanswered slot; a fresh answer stays for a minute. */
    fun quiz(db: SqlDb, clock: AppClock, rng: RandomSource): List<WidgetSnapshot> {
        val all = build(db, clock, rng, WidgetMode.CARD)
        val now = clock.now
        val first = all.indexOfFirst { it.quizAnswer == null && it.card != null }
        if (first < 0) return all
        val result = mutableListOf<WidgetSnapshot>()
        var start = now
        val seconds = Settings.string(db, SettingKey.QUIZ_ANSWERED_AT)?.toDoubleOrNull()
        if (first > 0 && seconds != null) {
            val until = Instant.ofEpochMilli((seconds * 1000).toLong()).plus(quizResultDuration)
            if (until > now) {
                result += all[first - 1].copy(date = now)
                start = until
            }
        }
        val next = all[first].let { it.copy(date = maxOf(start, minOf(it.date, now))) }
        result += next
        result += all.drop(first + 1).filter { it.date > next.date }
        return result
    }

    fun reviewCount(day: LocalDate, db: SqlDb): Int = db.int("SELECT COUNT(*) FROM review_log WHERE answered_on = ?", listOf(day))

    /** Struggling cards, most recently answered first. */
    fun strugglingCards(db: SqlDb, limit: Int): List<Card> = db.query(
        """SELECT c.* FROM card c JOIN card_state s ON s.card_id = c.id
           WHERE s.state = 'struggling' ORDER BY s.last_answered_on DESC, c.word LIMIT ?""",
        listOf(limit), Card::from,
    )

    /** Today's count now, and a reset at the next local midnight. */
    fun ringSnapshots(db: SqlDb, clock: AppClock): List<WidgetSnapshot> {
        val now = clock.now
        val today = clock.today
        val midnight = today.addingDays(1).startInstant(clock.zone)
        val card = db.query("SELECT * FROM card LIMIT 1", emptyList(), Card::from).firstOrNull()
        return listOf(
            WidgetSnapshot(date = now, card = card, reviewedToday = reviewCount(today, db)),
            WidgetSnapshot(date = midnight, card = card, reviewedToday = 0),
        )
    }
}

/** The logic behind widget and notification buttons. */
object WidgetActions {
    fun markKnown(cardID: String, db: SqlDb, clock: AppClock) {
        LearningStore.record(LearningEvent.MarkedKnown, cardID, ReviewSource.WIDGET, clock, db)
    }

    fun markStruggling(cardID: String, db: SqlDb, clock: AppClock) {
        LearningStore.record(LearningEvent.MarkedStruggling, cardID, ReviewSource.WIDGET, clock, db)
    }

    /** Records a quiz answer once per slot; null when no unanswered slot from now on shows the card. */
    fun answerQuiz(cardID: String, option: String, db: SqlDb, clock: AppClock): Boolean? = db.transaction {
        val current = WidgetQueue.current(db, clock) ?: return@transaction null
        val entry = db.query(
            "SELECT * FROM widget_queue WHERE slot_start >= ? AND card_id = ? ORDER BY slot_start LIMIT 1",
            listOf(current.slotStart, cardID), com.enesseval.kilitkelime.core.model.WidgetQueueEntry::from,
        ).firstOrNull() ?: return@transaction null
        if (entry.quizAnswer != null) return@transaction null
        val card = CardQueries.card(cardID, db) ?: return@transaction null
        val correct = option == card.word
        WidgetQueue.recordQuizAnswer(option, entry.slotStart, db)
        Settings.set(db, SettingKey.QUIZ_ANSWERED_AT, (clock.now.toEpochMilli() / 1000.0).toString())
        LearningStore.record(LearningEvent.Answered(correct), cardID, ReviewSource.WIDGET, clock, db)
        correct
    }
}
