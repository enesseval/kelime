package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.queries.StatsQueries
import java.time.LocalDate

/** Everything onboarding collects, saved in one transaction. */
data class OnboardingChoices(
    val level: CEFRLevel = CEFRLevel.B1,
    /** Minutes after midnight, or null when the reminder was skipped. */
    val reminderMinutes: Int? = null,
) {
    /** Decks to start with: the level deck, plus the basic word decks below B2. */
    val decks: List<DeckID>
        get() {
            val decks = mutableListOf(DeckID.forLevel(level))
            if (level > CEFRLevel.A1) {
                for (basic in DeckID.basicDecks) if (basic !in decks && level <= CEFRLevel.B1) decks += basic
            }
            return decks
        }

    fun save(db: SqlDb) = db.transaction {
        val prefs = Preferences.load(db)
        val enabled = if (level in Curriculum.levels(db)) decks.filter { it.level == level } else decks
        prefs.copy(level = level, enabledDecks = enabled).save(db)
        Settings.setInt(db, SettingKey.REMINDER_TIME, reminderMinutes)
        Settings.setBool(db, SettingKey.ONBOARDING_DONE, true)
    }
}

/** The optional exam countdown on Bugün. */
object ExamCountdown {
    val exams = listOf(DeckID.YDS, DeckID.YOKDIL, DeckID.IELTS)

    fun load(db: SqlDb): Pair<DeckID, LocalDate>? {
        val date = Settings.date(db, SettingKey.EXAM_DATE) ?: return null
        val exam = DeckID.fromRaw(Settings.string(db, SettingKey.EXAM)) ?: DeckID.YDS
        return exam to date
    }

    fun daysLeft(db: SqlDb, clock: AppClock): Pair<DeckID, Int>? {
        val (exam, date) = load(db) ?: return null
        val days = StatsQueries.daysUntilExam(date, clock) ?: return null
        return exam to days
    }

    fun set(exam: DeckID, date: LocalDate, db: SqlDb) {
        Settings.set(db, SettingKey.EXAM, exam.raw)
        Settings.setDate(db, SettingKey.EXAM_DATE, date)
    }

    fun clear(db: SqlDb) {
        Settings.set(db, SettingKey.EXAM, null)
        Settings.setDate(db, SettingKey.EXAM_DATE, null)
    }
}

object LevelSamples {
    fun words(level: CEFRLevel): List<String> = when (level) {
        CEFRLevel.A1 -> listOf("book", "happy", "water")
        CEFRLevel.A2 -> listOf("borrow", "famous", "journey")
        CEFRLevel.B1 -> listOf("reliable", "obvious", "achieve")
        CEFRLevel.B2 -> listOf("reluctant", "hesitate", "significant")
        CEFRLevel.C1 -> listOf("ambiguous", "meticulous", "mitigate")
        CEFRLevel.C2 -> listOf("ubiquitous", "ephemeral", "esoteric")
    }
}

/** Where the learner stands on the exam plan (Pro). */
data class ExamPlanStatus(
    val exam: DeckID,
    val daysLeft: Int,
    val remaining: Int,
    val dailyTarget: Int,
    val doneToday: Int,
    val listOnWidget: Boolean,
) {
    val fraction: Double get() = if (dailyTarget == 0) 1.0 else minOf(doneToday.toDouble() / dailyTarget, 1.0)
}

object ExamPlan {
    fun status(db: SqlDb, clock: AppClock): ExamPlanStatus? {
        val (exam, daysLeft) = ExamCountdown.daysLeft(db, clock) ?: return null
        val filter = CardQueries.deckFilter(listOf(exam)) ?: return null
        val remaining = db.int(
            Sql("SELECT COUNT(*) FROM card c LEFT JOIN card_state s ON s.card_id = c.id WHERE ") + filter +
                " AND COALESCE(s.state, 'new') <> 'learned'",
        )
        val doneToday = db.int(
            Sql("SELECT COUNT(DISTINCT r.card_id) FROM review_log r JOIN card c ON c.id = r.card_id WHERE r.answered_on = ? AND ", listOf(clock.today)) + filter,
        )
        val days = maxOf(daysLeft, 1)
        val target = if (remaining == 0) 0 else minOf(maxOf(Math.ceil(remaining.toDouble() / days).toInt(), 1), remaining)
        return ExamPlanStatus(exam, daysLeft, remaining, target, doneToday, exam in Preferences.load(db).enabledDecks)
    }
}
