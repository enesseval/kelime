package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.queries.StatsQueries
import java.time.LocalDate

/**
 * The reverse trial (docs/V1_2_PLAN.md §2): from the first launch everything is open for 72 hours,
 * no card needed. Pro = purchase or a running trial. The start lives in the app's database (app data);
 * the latest time seen is kept too, so setting the clock back cannot stretch the trial.
 */
object FreeTrial {
    const val DURATION_MS = 72L * 3600 * 1000
    private const val DAY_MS = 24L * 3600 * 1000

    data class Status(val started: Boolean, val active: Boolean, val remainingMs: Long) {
        /** "Deneme: N gün kaldı": whole days, rounded up (72 h = 3). */
        val daysLeft: Int get() = if (!active) 0 else ((remainingMs + DAY_MS - 1) / DAY_MS).toInt()
        val ended: Boolean get() = started && !active
    }

    /** Starts the trial at the first launch; later calls change nothing. True when it started now. */
    fun startIfNeeded(db: SqlDb, nowMs: Long): Boolean {
        if (Settings.string(db, SettingKey.TRIAL_START) != null) return false
        Settings.set(db, SettingKey.TRIAL_START, nowMs.toString())
        Settings.set(db, SettingKey.TRIAL_SEEN, nowMs.toString())
        return true
    }

    /** The trial's state. Time never runs backwards: the later of [nowMs] and the latest time seen counts. */
    fun status(db: SqlDb, nowMs: Long): Status {
        val start = Settings.string(db, SettingKey.TRIAL_START)?.toLongOrNull() ?: return Status(false, false, 0)
        val seen = Settings.string(db, SettingKey.TRIAL_SEEN)?.toLongOrNull() ?: start
        val now = maxOf(nowMs, seen)
        if (now > seen) Settings.set(db, SettingKey.TRIAL_SEEN, now.toString())
        val remaining = start + DURATION_MS - now
        return Status(true, remaining > 0, maxOf(remaining, 0))
    }

    /** Pro for every rule in the app. */
    fun isPro(db: SqlDb, nowMs: Long): Boolean = Settings.bool(db, SettingKey.PURCHASED) || status(db, nowMs).active

    /** True once, when the ended trial is first noticed (sends `trial.ended`). */
    fun takeEnded(db: SqlDb, nowMs: Long): Boolean {
        if (!status(db, nowMs).ended || Settings.bool(db, SettingKey.TRIAL_ENDED_SENT)) return false
        Settings.setBool(db, SettingKey.TRIAL_ENDED_SENT, true)
        return true
    }

    /** The one-time summary page: the trial ended, nothing was bought, it was not shown yet. */
    fun summaryDue(db: SqlDb, nowMs: Long): Boolean =
        status(db, nowMs).ended && !Settings.bool(db, SettingKey.PURCHASED) && !Settings.bool(db, SettingKey.TRIAL_SUMMARY_SHOWN)

    fun markSummaryShown(db: SqlDb) = Settings.setBool(db, SettingKey.TRIAL_SUMMARY_SHOWN, true)

    /** Counted for the summary while the trial runs. */
    fun noteArchive(db: SqlDb, day: LocalDate, nowMs: Long) {
        if (!status(db, nowMs).active) return
        val days = archiveDays(db)
        if (day.toString() in days) return
        Settings.set(db, SettingKey.TRIAL_ARCHIVE_DAYS, (days + day.toString()).joinToString(","))
    }

    fun notePersonal(db: SqlDb, nowMs: Long) {
        if (!status(db, nowMs).active) return
        Settings.setInt(db, SettingKey.TRIAL_PERSONAL, (Settings.int(db, SettingKey.TRIAL_PERSONAL) ?: 0) + 1)
    }

    private fun archiveDays(db: SqlDb): List<String> =
        Settings.string(db, SettingKey.TRIAL_ARCHIVE_DAYS)?.split(',')?.filter { it.isNotEmpty() } ?: emptyList()

    /** What the learner used in the 3 days, with numbers; zero counts are left out by the screen. */
    data class Summary(val archivePuzzles: Int, val personalPuzzles: Int, val ownLists: Int, val examPercent: Int?)

    fun summary(db: SqlDb, clock: AppClock): Summary {
        val plan = ExamPlan.status(db, clock)
        val percent = plan?.let {
            val filter = CardQueries.deckFilter(listOf(it.exam))
            val total = filter?.let { f -> db.int(Sql("SELECT COUNT(*) FROM card c WHERE ") + f) } ?: 0
            if (total == 0) null else ((total - it.remaining) * 100.0 / total).toInt().coerceIn(0, 100)
        }
        return Summary(
            archiveDays(db).size,
            Settings.int(db, SettingKey.TRIAL_PERSONAL) ?: 0,
            db.int("SELECT COUNT(*) FROM user_list WHERE imported = 0"),
            percent,
        )
    }
}

/**
 * Free learners may open 2 archive puzzles a week (the week starts Monday); Pro opens any
 * (docs/V1_2_PLAN.md §2). A puzzle opened this week, or one already played, opens again at no cost.
 */
object ArchiveQuota {
    const val FREE_PER_WEEK = 2

    /** Days (ISO) whose archive puzzle was opened in [today]'s week. */
    fun used(db: SqlDb, today: LocalDate): List<String> {
        val stored = Settings.string(db, SettingKey.ARCHIVE_QUOTA) ?: return emptyList()
        val parts = stored.split('|', limit = 2)
        if (parts[0] != StatsQueries.weekStart(today).toString()) return emptyList()
        return parts.getOrElse(1) { "" }.split(',').filter { it.isNotEmpty() }
    }

    fun left(db: SqlDb, today: LocalDate, isPro: Boolean): Int =
        if (isPro) Int.MAX_VALUE else maxOf(0, FREE_PER_WEEK - used(db, today).size)

    fun canOpen(db: SqlDb, today: LocalDate, day: LocalDate, isPro: Boolean, alreadyPlayed: Boolean): Boolean {
        if (isPro || alreadyPlayed) return true
        val used = used(db, today)
        return day.toString() in used || used.size < FREE_PER_WEEK
    }

    /** Spends one of the week's two on [day] (nothing when it is already counted, or Pro). */
    fun consume(db: SqlDb, today: LocalDate, day: LocalDate, isPro: Boolean) {
        if (isPro) return
        val days = used(db, today)
        if (day.toString() in days) return
        Settings.set(db, SettingKey.ARCHIVE_QUOTA, StatsQueries.weekStart(today).toString() + "|" + (days + day.toString()).joinToString(","))
    }
}
