package com.enesseval.kilitkelime.core.queries

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.dates.daysSince
import com.enesseval.kilitkelime.core.dates.startInstant
import com.enesseval.kilitkelime.core.games.Streak
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.strings
import java.time.DayOfWeek
import java.time.LocalDate

/** Gentle weekly tracking. Missing a day shows nothing negative. */
data class WeekStats(
    val learnedThisWeek: Int,
    val strugglingNow: Int,
    val days: List<Day>,
    val streak: Int = 0,
) {
    data class Day(val date: LocalDate, val reviewed: Boolean, val initial: String)
}

/** A week in numbers, for the Monday summary (docs/V1_1_PLAN.md §1). */
data class WeeklySummary(
    val weekStart: LocalDate,
    /** Words that became (or were confirmed) learned that week. */
    val learned: Int,
    /** Words answered wrong that week that are still struggling. */
    val struggling: Int,
    /** Words the lock screen showed that week (shown slots). */
    val shown: Int,
    /** Quick Review accuracy in percent; null without Quick Review answers. */
    val quickReviewAccuracy: Int?,
    val streak: Int,
    /** The word missed most often that ended up learned that week. */
    val wordOfWeek: Card?,
) {
    /** Something happened that week worth a summary. */
    val hasContent: Boolean get() = learned > 0 || struggling > 0 || shown > 0 || quickReviewAccuracy != null
}

object StatsQueries {
    val weekdayInitials = listOf("P", "S", "Ç", "P", "C", "C", "P")

    fun weekStart(day: LocalDate): LocalDate = day.minusDays((day.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())

    private fun studiedDays(db: SqlDb, from: LocalDate, to: LocalDate): Set<LocalDate> =
        db.strings("SELECT DISTINCT answered_on FROM review_log WHERE answered_on BETWEEN ? AND ?", listOf(from, to))
            .mapNotNull(LocalDates::parse).toSet()

    /** This week's dots (days with any answer, as on iOS 1.0) and the 1.1 streak. */
    fun week(db: SqlDb, clock: AppClock, isPro: Boolean = false): WeekStats {
        val today = clock.today
        val start = weekStart(today)
        val end = start.addingDays(6)
        val learned = db.int(
            "SELECT COUNT(*) FROM card_state WHERE state = 'learned' AND last_answered_on BETWEEN ? AND ?",
            listOf(start, end),
        )
        val struggling = db.int("SELECT COUNT(*) FROM card_state WHERE state = 'struggling'")
        val reviewed = studiedDays(db, start, end)
        val days = (0 until 7).map { i ->
            val d = start.addingDays(i)
            WeekStats.Day(d, d in reviewed, weekdayInitials[i])
        }
        return WeekStats(learned, struggling, days, streak(db, clock, isPro))
    }

    /** The 1.1 streak (see [Streak]). */
    fun streak(db: SqlDb, clock: AppClock, isPro: Boolean = false): Int = Streak.status(db, clock, isPro).current

    /** The summary of the week starting [weekStart] (Monday). */
    fun weekly(db: SqlDb, clock: AppClock, weekStart: LocalDate, isPro: Boolean = false): WeeklySummary {
        val end = weekStart.addingDays(6)
        val learned = db.int(
            "SELECT COUNT(*) FROM card_state WHERE state = 'learned' AND last_answered_on BETWEEN ? AND ?",
            listOf(weekStart, end),
        )
        val struggling = db.int(
            """SELECT COUNT(DISTINCT r.card_id) FROM review_log r JOIN card_state s ON s.card_id = r.card_id
               WHERE r.correct = 0 AND s.state = 'struggling' AND r.answered_on BETWEEN ? AND ?""",
            listOf(weekStart, end),
        )
        val shown = db.int(
            "SELECT COUNT(*) FROM widget_shown WHERE slot_start >= ? AND slot_start < ?",
            listOf(weekStart.startInstant(clock.zone), end.addingDays(1).startInstant(clock.zone)),
        )
        val (answers, correct) = db.query(
            """SELECT COUNT(*) AS n, SUM(CASE WHEN correct = 1 THEN 1 ELSE 0 END) AS ok FROM review_log
               WHERE source = 'quickReview' AND answered_on BETWEEN ? AND ?""",
            listOf(weekStart, end),
        ) { (it.int("n") ?: 0) to (it.int("ok") ?: 0) }.first()
        val word = db.query(
            """SELECT c.*, (SELECT COUNT(*) FROM review_log r WHERE r.card_id = c.id AND r.correct = 0) AS misses
               FROM card c JOIN card_state s ON s.card_id = c.id
               WHERE s.state = 'learned' AND s.last_answered_on BETWEEN ? AND ? AND misses > 0
               ORDER BY misses DESC, c.word LIMIT 1""",
            listOf(weekStart, end),
            Card::from,
        ).firstOrNull()
        return WeeklySummary(
            weekStart, learned, struggling, shown,
            if (answers == 0) null else Math.round(correct * 100.0 / answers).toInt(),
            streak(db, clock, isPro), word,
        )
    }

    /** Last week's summary: shown on Mondays. */
    fun lastWeek(db: SqlDb, clock: AppClock, isPro: Boolean = false): WeeklySummary =
        weekly(db, clock, weekStart(clock.today).addingDays(-7), isPro)

    fun daysUntilExam(examDate: LocalDate?, clock: AppClock): Int? {
        examDate ?: return null
        val days = examDate.daysSince(clock.today)
        return if (days >= 0) days else null
    }
}
