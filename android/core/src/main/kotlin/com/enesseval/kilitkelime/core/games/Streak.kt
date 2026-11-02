package com.enesseval.kilitkelime.core.games

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.queries.StatsQueries
import java.time.LocalDate

/**
 * What counted a day for the streak (`streak_day.source`, and the `source` parameter of the
 * `streak.day` signal). The same values as iOS: quickReview, puzzle, wordSearch, match.
 */
enum class StreakSource(val raw: String) {
    QUICK_REVIEW("quickReview"), PUZZLE("puzzle"), WORD_SEARCH("wordSearch"), MATCH("match"),
}

/** The streak as Bugün and the streak page show it. */
data class StreakStatus(
    /** Studied days in a row up to today (or yesterday while today is still open). */
    val current: Int,
    val longest: Int,
    val studiedToday: Boolean,
    /** Today is open and the streak would end at midnight without a round. */
    val atRisk: Boolean,
    /** Missed days the weekly freeze saved. */
    val frozen: Set<LocalDate>,
    val studied: Set<LocalDate>,
    val freezesLeftThisWeek: Int,
)

/**
 * The 1.1 streak rules (docs/V1_1_PLAN.md §1), pure.
 *
 * A day counts when it is in [studied]. A single missed day between two studied days (or between
 * a studied day and today, while today is open) is saved by the weekly freeze: one per Monday–Sunday
 * week, two with Pro. Freezes are spent in calendar order. Two missed days in a row end the streak.
 */
object Streak {
    const val FREE_FREEZES = 1
    const val PRO_FREEZES = 2
    val milestones = listOf(7, 30, 100)
    private const val HISTORY_DAYS = 400

    fun freezesPerWeek(isPro: Boolean) = if (isPro) PRO_FREEZES else FREE_FREEZES

    fun compute(studied: Set<LocalDate>, today: LocalDate, freezesPerWeek: Int, storedLongest: Int = 0): StreakStatus {
        val start = studied.filter { it <= today }.minOrNull() ?: today
        var run = 0
        var longest = 0
        val frozen = mutableSetOf<LocalDate>()
        val used = HashMap<LocalDate, Int>()
        var day = start
        while (day <= today) {
            when {
                day in studied -> {
                    run++
                    longest = maxOf(longest, run)
                }
                day == today -> {} // still open
                run > 0 && (day.addingDays(1) in studied || day.addingDays(1) == today) &&
                    (used[StatsQueries.weekStart(day)] ?: 0) < freezesPerWeek -> {
                    frozen += day
                    used.merge(StatsQueries.weekStart(day), 1, Int::plus)
                }
                else -> run = 0
            }
            day = day.addingDays(1)
        }
        val studiedToday = today in studied
        return StreakStatus(
            current = run,
            longest = maxOf(longest, storedLongest),
            studiedToday = studiedToday,
            atRisk = !studiedToday && run > 0,
            frozen = frozen,
            studied = studied,
            freezesLeftThisWeek = maxOf(0, freezesPerWeek - (used[StatsQueries.weekStart(today)] ?: 0)),
        )
    }

    fun studiedDays(db: SqlDb, from: LocalDate, to: LocalDate): Set<LocalDate> =
        db.strings("SELECT day FROM streak_day WHERE day BETWEEN ? AND ?", listOf(from, to)).mapNotNull(LocalDates::parse).toSet()

    /** The streak now; also keeps the longest streak in `settings` (it outlives the history window). */
    fun status(db: SqlDb, clock: AppClock, isPro: Boolean): StreakStatus {
        val today = clock.today
        val stored = Settings.int(db, SettingKey.LONGEST_STREAK) ?: 0
        val status = compute(studiedDays(db, today.addingDays(-HISTORY_DAYS), today), today, freezesPerWeek(isPro), stored)
        if (status.longest > stored) Settings.setInt(db, SettingKey.LONGEST_STREAK, status.longest)
        return status
    }

    /** The milestone just reached today (7, 30, 100), for the share card. */
    fun milestone(status: StreakStatus): Int? = milestones.lastOrNull { it == status.current }?.takeIf { status.studiedToday }

    /** The five Monday-first weeks ending with this week, oldest first. */
    fun calendar(today: LocalDate): List<List<LocalDate>> {
        val first = StatsQueries.weekStart(today).addingDays(-28)
        return (0 until 5).map { w -> (0 until 7).map { d -> first.addingDays(w * 7 + d) } }
    }
}
