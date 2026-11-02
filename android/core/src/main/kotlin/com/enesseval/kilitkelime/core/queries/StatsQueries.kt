package com.enesseval.kilitkelime.core.queries

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.dates.daysSince
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

/** Last week in numbers, for the Monday summary (1.1). */
data class WeeklySummary(
    val weekStart: LocalDate,
    val answers: Int,
    val correct: Int,
    val learned: Int,
    val daysStudied: Int,
)

object StatsQueries {
    val weekdayInitials = listOf("P", "S", "Ç", "P", "C", "C", "P")

    fun weekStart(day: LocalDate): LocalDate = day.minusDays((day.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())

    private fun studiedDays(db: SqlDb, from: LocalDate, to: LocalDate): Set<LocalDate> =
        (db.strings("SELECT DISTINCT answered_on FROM review_log WHERE answered_on BETWEEN ? AND ?", listOf(from, to)) +
            db.strings("SELECT day FROM streak_day WHERE day BETWEEN ? AND ?", listOf(from, to)))
            .mapNotNull(LocalDates::parse).toSet()

    fun week(db: SqlDb, clock: AppClock): WeekStats {
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
        return WeekStats(learned, struggling, days, streak(db, clock))
    }

    /** Days in a row with an answer or a finished game, ending today (or yesterday). */
    fun streak(db: SqlDb, clock: AppClock): Int {
        val today = clock.today
        val days = studiedDays(db, today.addingDays(-400), today)
        var day = if (today in days) today else today.addingDays(-1)
        var count = 0
        while (day in days) {
            count += 1
            day = day.addingDays(-1)
        }
        return count
    }

    /** The week before the current one. */
    fun lastWeek(db: SqlDb, clock: AppClock): WeeklySummary {
        val start = weekStart(clock.today).addingDays(-7)
        val end = start.addingDays(6)
        val answers = db.int("SELECT COUNT(*) FROM review_log WHERE answered_on BETWEEN ? AND ?", listOf(start, end))
        val correct = db.int("SELECT COUNT(*) FROM review_log WHERE correct = 1 AND answered_on BETWEEN ? AND ?", listOf(start, end))
        val learned = db.int(
            """SELECT COUNT(DISTINCT r.card_id) FROM review_log r JOIN card_state s ON s.card_id = r.card_id
               WHERE s.state = 'learned' AND r.answered_on BETWEEN ? AND ?""",
            listOf(start, end),
        )
        return WeeklySummary(start, answers, correct, learned, studiedDays(db, start, end).size)
    }

    fun daysUntilExam(examDate: LocalDate?, clock: AppClock): Int? {
        examDate ?: return null
        val days = examDate.daysSince(clock.today)
        return if (days >= 0) days else null
    }
}
