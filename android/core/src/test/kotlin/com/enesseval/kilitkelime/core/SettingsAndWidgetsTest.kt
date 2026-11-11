package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.startInstant
import com.enesseval.kilitkelime.core.db.Migrations
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.ProgressReset
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.ExamCountdown
import com.enesseval.kilitkelime.core.model.ExamPlan
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.LevelSamples
import com.enesseval.kilitkelime.core.model.OnboardingChoices
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.ProEntitlement
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.model.RotationInterval
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.core.model.WidgetThemeID
import com.enesseval.kilitkelime.core.queries.DeckQueries
import com.enesseval.kilitkelime.core.widgets.WidgetActions
import com.enesseval.kilitkelime.core.widgets.WidgetLog
import com.enesseval.kilitkelime.core.widgets.WidgetSnapshot
import com.enesseval.kilitkelime.core.widgets.WidgetTimelineBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class OnboardingTest {
    private val clock = AppClock.fixed(Instant.parse("2026-10-22T09:00:00Z"), ZoneId.of("Europe/Istanbul"))

    @Test fun savesChoicesAndFinishesOnboarding() {
        val db = TestSupport.database()
        OnboardingChoices(CEFRLevel.B2, 20 * 60 + 30).save(db)
        val prefs = Preferences.load(db)
        assertEquals(CEFRLevel.B2, prefs.level)
        assertEquals(listOf(DeckID.B2), prefs.enabledDecks)
        assertEquals(RotationInterval.THREE_HOURS, prefs.effectiveRotation)
        assertNull(ExamCountdown.load(db))
        assertEquals(1230, Settings.int(db, SettingKey.REMINDER_TIME))
        assertTrue(Settings.bool(db, SettingKey.ONBOARDING_DONE))
    }

    @Test fun everyDeckIsFree() {
        val choices = OnboardingChoices(CEFRLevel.C1)
        assertEquals(listOf(DeckID.C1), choices.decks)
        assertEquals(listOf(DeckID.C1), DeckID.entitled(choices.decks))
        assertEquals(DeckID.basicDecks, DeckID.entitled(emptyList()))
    }

    @Test fun withoutProTheRotationIsThreeHours() {
        for (interval in RotationInterval.entries) {
            assertEquals(RotationInterval.THREE_HOURS, interval.effective(false))
            assertEquals(interval, interval.effective(true))
        }
        assertEquals(8, RotationInterval.THREE_HOURS.perDay)
        assertEquals(48, RotationInterval.THIRTY_MINUTES.perDay)
    }

    @Test fun examCountdown() {
        val db = TestSupport.database()
        Settings.setDate(db, SettingKey.EXAM_DATE, LocalDate.of(2026, 11, 1))
        assertEquals(DeckID.YDS to 10, ExamCountdown.daysLeft(db, clock))
        ExamCountdown.set(DeckID.IELTS, LocalDate.of(2026, 10, 21), db)
        assertNull(ExamCountdown.daysLeft(db, clock))
        assertEquals(DeckID.IELTS, ExamCountdown.load(db)?.first)
        ExamCountdown.clear(db)
        assertNull(ExamCountdown.load(db))
    }

    @Test fun themesFollowEntitlement() {
        assertEquals(WidgetThemeID.PAPER, WidgetThemeID.EMBER.effective(false))
        assertEquals(WidgetThemeID.EMBER, WidgetThemeID.EMBER.effective(true))
        val db = TestSupport.database()
        Preferences.load(db).copy(theme = WidgetThemeID.MONO).save(db)
        val prefs = Preferences.load(db)
        assertTrue(prefs.theme == WidgetThemeID.MONO && prefs.effectiveTheme == WidgetThemeID.PAPER)
    }

    @Test fun examPlanSpreadsTheListOverTheDaysLeft() {
        val db = TestSupport.bundled(Preferences(level = CEFRLevel.B1, enabledDecks = listOf(DeckID.B1)))
        assertNull(ExamPlan.status(db, clock))
        ExamCountdown.set(DeckID.YDS, LocalDate.of(2026, 11, 1), db)
        LearningStore.record(LearningEvent.Answered(true), "exam-hamper", ReviewSource.QUICK_REVIEW, clock, db)
        val plan = ExamPlan.status(db, clock)!!
        val total = DeckQueries.progress(db).first { it.deck == DeckID.YDS }.total
        assertTrue(plan.exam == DeckID.YDS && plan.daysLeft == 10)
        assertEquals(total - 1, plan.remaining)
        assertEquals(Math.ceil((total - 1) / 10.0).toInt(), plan.dailyTarget)
        assertTrue(plan.doneToday == 1 && !plan.listOnWidget)
    }

    @Test fun levelSamplesHaveThreeWords() {
        for (level in CEFRLevel.entries) assertEquals(3, LevelSamples.words(level).size)
    }
}

class ProgressResetTest {
    @Test fun startsOverButKeepsContentAndPurchase() {
        val db = TestSupport.bundled(Preferences(level = CEFRLevel.B1))
        val count = db.int("SELECT COUNT(*) FROM card")
        val version = Settings.int(db, SettingKey.CONTENT_VERSION)
        Settings.setBool(db, SettingKey.IS_PRO, true)
        Settings.setBool(db, SettingKey.ONBOARDING_DONE, true)
        Curriculum.start("a1-cafe", db)
        CardState("a1-cafe", LearningState.LEARNED).save(db)
        assertTrue(ProgressReset.resetIfNeeded(db))
        assertEquals(0, db.int("SELECT COUNT(*) FROM card_state"))
        assertFalse(Settings.bool(db, SettingKey.ONBOARDING_DONE))
        assertNull(Settings.string(db, SettingKey.UNITS_STARTED))
        assertEquals(version, Settings.int(db, SettingKey.CONTENT_VERSION))
        assertTrue(Settings.bool(db, SettingKey.IS_PRO))
        assertEquals(listOf(DeckID.A1), Preferences.load(db).enabledDecks)
        assertTrue(CardQueries.candidates(listOf(DeckID.A1), db).all { CardQueries.card(it.cardID, db)?.level == CEFRLevel.A1 })
        assertEquals(count, db.int("SELECT COUNT(*) FROM card"))
        assertFalse(ProgressReset.resetIfNeeded(db))
    }

    @Test fun onlyLevelsWithUnitsArePickable() {
        assertEquals(CEFRLevel.entries, Curriculum.levels(TestSupport.bundled()))
    }

    @Test fun migrationsAreIdempotentAndReachTheLatestVersion() {
        val db = TestSupport.database()
        assertEquals(Migrations.latest, db.int("PRAGMA user_version"))
        Migrations.migrate(db)
        assertEquals(Migrations.latest, db.int("PRAGMA user_version"))
    }

    @Test fun v7BackfillsStreakDaysFromReviews() {
        val db = JdbcSqlDb(java.sql.DriverManager.getConnection("jdbc:sqlite::memory:"))
        Migrations.migrate(db, 0)
        db.execute("DELETE FROM streak_day")
        db.execute("PRAGMA user_version = 6")
        db.execute("DROP TABLE streak_day")
        db.execute("DROP TABLE game_result")
        db.execute("DROP TABLE widget_shown")
        db.execute("INSERT INTO review_log (card_id, answered_at, answered_on, correct, source) VALUES ('x', 0, '2026-10-01', 1, 'quickReview')")
        db.execute("INSERT INTO review_log (card_id, answered_at, answered_on, correct, source) VALUES ('x', 0, '2026-10-02', 1, 'widget')")
        Migrations.migrate(db)
        // Quick Review and puzzle days count; widget answers do not.
        assertEquals(listOf("2026-10-01"), db.strings("SELECT day FROM streak_day"))
    }
}

class WidgetTimelineTest {
    private val istanbul = ZoneId.of("Europe/Istanbul")
    private val start = Instant.parse("2026-10-13T07:20:00Z")
    private fun clock(offset: Long = 0) = AppClock.fixed(start.plusSeconds(offset), istanbul)
    private fun build(db: JdbcSqlDb, mode: WidgetMode? = null) = WidgetTimelineBuilder.build(db, clock(), SeededGenerator(5u), mode)

    @Test fun emptyDatabaseGivesTheEmptyState() {
        val snapshots = build(TestSupport.database())
        assertEquals(1, snapshots.size)
        assertTrue(snapshots[0].isEmpty)
    }

    @Test fun cardModeHasOneEntryPerSlot() {
        val snapshots = build(TestSupport.bundled())
        assertEquals(25, snapshots.size)
        assertTrue(snapshots.all { it.mode == WidgetMode.CARD && it.phase == WidgetSnapshot.Phase.ANSWER && it.card != null })
        assertEquals(snapshots.map { it.date }.sorted(), snapshots.map { it.date })
        // Every snapshot knows the word before it (the self-test answer on the wallpaper).
        assertTrue(snapshots.drop(1).zip(snapshots).all { (s, prev) -> s.previousCard == prev.card })
    }

    @Test fun modeDefaultsToTheAppSetting() {
        val db = TestSupport.bundled(Preferences(defaultWidgetMode = WidgetMode.SENTENCE))
        assertTrue(build(db).all { it.mode == WidgetMode.SENTENCE })
        assertTrue(build(db, WidgetMode.CARD).all { it.mode == WidgetMode.CARD })
    }

    /**
     * Kendini sına cycles inside a slot: question 20 minutes, answer 10, and again. The old
     * single question (first 30 minutes of three hours) left the answer on screen most of the day.
     */
    @Test fun selfTestCyclesQuestionAndAnswerInsideASlot() {
        val threeHours = build(TestSupport.bundled(), WidgetMode.SELF_TEST)
        val firstSlot = threeHours.filter { it.slotStart == threeHours[0].slotStart }
        assertEquals(12, firstSlot.size)
        assertEquals(listOf(0L, 20, 30, 50, 60, 80, 90, 110, 120, 140, 150, 170), firstSlot.map { Duration.between(it.slotStart, it.date).toMinutes() })
        assertTrue(firstSlot.withIndex().all { (i, s) -> s.phase == if (i % 2 == 0) WidgetSnapshot.Phase.QUESTION else WidgetSnapshot.Phase.ANSWER })
        assertEquals(1, firstSlot.map { it.card }.toSet().size)
        // 95 minutes into the slot the learner sees the question, not the answer.
        val at = threeHours[0].slotStart.plus(Duration.ofMinutes(95))
        assertEquals(WidgetSnapshot.Phase.QUESTION, threeHours.last { it.date <= at }.phase)
        assertEquals(threeHours.map { it.date }.sorted(), threeHours.map { it.date })
        // Slots more than a day away keep one question and one answer.
        val lastSlot = threeHours.filter { it.slotStart == threeHours.last().slotStart }
        assertEquals(listOf(WidgetSnapshot.Phase.QUESTION, WidgetSnapshot.Phase.ANSWER), lastSlot.map { it.phase })

        val halfHourly = build(TestSupport.bundled(Preferences(rotationInterval = RotationInterval.THIRTY_MINUTES, isPro = true)), WidgetMode.SELF_TEST)
        assertTrue(halfHourly[0].phase == WidgetSnapshot.Phase.QUESTION && halfHourly[1].phase == WidgetSnapshot.Phase.ANSWER)
        assertEquals(Duration.ofMinutes(20), Duration.between(halfHourly[0].date, halfHourly[1].date))
        assertTrue(halfHourly[2].slotStart != halfHourly[0].slotStart)

        // The wallpaper refreshes at the next phase change: 10:20 is in the 09:00 slot's answer (10:20–10:30).
        val slotStart = threeHours[0].slotStart
        assertEquals(slotStart.plus(Duration.ofMinutes(90)), WidgetTimelineBuilder.nextSelfTestChange(slotStart, RotationInterval.THREE_HOURS, start))
        assertNull(WidgetTimelineBuilder.nextSelfTestChange(slotStart, RotationInterval.THREE_HOURS, slotStart.plus(Duration.ofMinutes(175))))
    }

    @Test fun snapshotsCarryStateQuizAndStruggling() {
        val db = TestSupport.bundled()
        val cardID = build(db)[0].card!!.id
        WidgetActions.markStruggling(cardID, db, clock())
        val again = build(db)[0]
        assertEquals(cardID, again.card?.id)
        assertEquals(LearningState.STRUGGLING, again.state)
        assertEquals(listOf(cardID), again.struggling.map { it.id })
        assertEquals(2, again.quizOptions.size)
        assertNull(again.quizCorrect)
    }

    @Test fun quizAnswerIsRecordedOncePerSlot() {
        val db = TestSupport.bundled()
        val first = build(db)[0]
        val card = first.card!!
        val wrong = first.quizOptions.first { it != card.word }
        assertEquals(false, WidgetActions.answerQuiz(card.id, wrong, db, clock()))
        assertNull(WidgetActions.answerQuiz(card.id, card.word, db, clock()))
        val after = build(db)[0]
        assertEquals(wrong, after.quizAnswer)
        assertEquals(false, after.quizCorrect)
        assertEquals(LearningState.STRUGGLING, after.state)
        assertEquals(1, after.reviewedToday)
    }

    @Test fun quizForAnotherCardIsIgnored() {
        val db = TestSupport.bundled()
        build(db)
        assertNull(WidgetActions.answerQuiz("not-current", "x", db, clock()))
    }

    @Test fun reviewCountResetsOnTheNextLocalDay() {
        val db = TestSupport.bundled()
        repeat(3) { LearningStore.record(LearningEvent.Answered(true), "b1-curious", ReviewSource.QUICK_REVIEW, clock(), db) }
        val snapshots = build(db)
        val todays = snapshots.filter { LocalDates.of(it.date, istanbul).toString() == "2026-10-13" }
        val tomorrows = snapshots.filter { LocalDates.of(it.date, istanbul).toString() == "2026-10-14" }
        assertTrue(todays.isNotEmpty() && tomorrows.isNotEmpty())
        assertTrue(todays.all { it.reviewedToday == 3 })
        assertTrue(tomorrows.all { it.reviewedToday == 0 })
        val ring = WidgetTimelineBuilder.ringSnapshots(db, clock())
        assertEquals(listOf(3, 0), ring.map { it.reviewedToday })
        assertEquals(LocalDate.of(2026, 10, 14).startInstant(istanbul), ring[1].date)
    }

    @Test fun markKnownLearnsTheCard() {
        val db = TestSupport.bundled()
        val card = build(db)[0].card!!
        WidgetActions.markKnown(card.id, db, clock())
        assertEquals(LearningState.LEARNED, build(db)[0].state)
    }

    @Test fun currentPicksTheSnapshotOnScreen() {
        val db = TestSupport.bundled()
        // 09:05 in Istanbul: the 09:00 slot shows its question until 09:20, then the answer until 09:30.
        val slotStart = AppClock.fixed(Instant.parse("2026-10-13T06:05:00Z"), istanbul)
        val atStart = WidgetTimelineBuilder.current(db, slotStart, SeededGenerator(5u), WidgetMode.SELF_TEST)
        assertEquals(WidgetSnapshot.Phase.QUESTION, atStart.phase)
        val later = WidgetTimelineBuilder.current(db, AppClock.fixed(Instant.parse("2026-10-13T06:25:00Z"), istanbul), SeededGenerator(5u), WidgetMode.SELF_TEST)
        assertEquals(WidgetSnapshot.Phase.ANSWER, later.phase)
        assertEquals(atStart.card, later.card)
    }
}

class WidgetLogTest {
    private val start = Instant.parse("2026-10-13T07:20:00Z")
    private fun clock(offset: Long = 0) = AppClock.fixed(start.plusSeconds(offset), ZoneId.of("Europe/Istanbul"))

    @Test fun tapsCompareTheShownEntryWithTheSchedule() {
        val db = TestSupport.bundled(Preferences(rotationInterval = RotationInterval.THIRTY_MINUTES, isPro = true))
        val queue = WidgetQueue.refill(db, clock(), SeededGenerator(3u))
        WidgetLog.recordTap("lock", queue[0].cardID, queue[0].slotStart, db, clock())
        WidgetLog.recordTap("lock", queue[0].cardID, queue[0].slotStart, db, clock(50 * 60))
        val rows = WidgetLog.recent(db)
        val late = rows.first()
        val onTime = rows.last()
        assertTrue(onTime.onTime == true && onTime.lag == null)
        assertEquals(false, late.onTime)
        assertEquals(Duration.ofMinutes(10), late.lag)
    }

    @Test fun updatesRecordWhatTheWallpaperDrew() {
        val db = TestSupport.bundled()
        val queue = WidgetQueue.refill(db, clock(), SeededGenerator(3u))
        WidgetLog.recordUpdate("wallpaper", queue[0].cardID, queue[0].slotStart, queue[1].slotStart, db, clock(5))
        val row = WidgetLog.recent(db).single()
        assertEquals(true, row.onTime)
        assertEquals(queue[1].slotStart, row.reloadAt)
    }

    @Test fun logIsPruned() {
        val db = TestSupport.database()
        db.transaction { repeat(3050) { WidgetLog.recordAppReload("$it", db, clock(it.toLong())) } }
        assertEquals(3000, db.int("SELECT COUNT(*) FROM widget_log"))
    }
}

class ProEntitlementTest {
    @Test fun activeProductsGrantPro() {
        assertTrue(ProEntitlement.isPro(listOf("pro.lifetime")))
        assertTrue(ProEntitlement.isPro(listOf("other", "pro.yearly")))
        assertFalse(ProEntitlement.isPro(emptyList()))
        assertTrue(ProEntitlement.isPro(listOf("pro.monthly")))
        assertTrue(ProEntitlement.isPro(listOf("pro.yearly:yearly-base")))
        assertFalse(ProEntitlement.isPro(listOf("pro.weekly")))
    }

    @Test fun cacheReportsChanges() {
        val db = TestSupport.database()
        assertFalse(ProEntitlement.cache(false, db))
        assertTrue(ProEntitlement.cache(true, db))
        assertFalse(ProEntitlement.cache(true, db))
        assertTrue(Settings.bool(db, SettingKey.IS_PRO))
        assertTrue(ProEntitlement.cache(false, db))
    }

    @Test fun proUnlocksFasterRotation() {
        val db = TestSupport.database()
        assertEquals(RotationInterval.THREE_HOURS, Preferences.load(db).copy(rotationInterval = RotationInterval.THIRTY_MINUTES).effectiveRotation)
        ProEntitlement.cache(true, db)
        assertEquals(RotationInterval.THIRTY_MINUTES, Preferences.load(db).copy(rotationInterval = RotationInterval.THIRTY_MINUTES).effectiveRotation)
    }

    @Test fun contentImportKeepsThePurchase() {
        val db = TestSupport.database()
        ProEntitlement.cache(true, db)
        ContentImporter.importIfNeeded(TestSupport.cardsJSON(1, listOf(TestSupport.card("x") to listOf(com.enesseval.kilitkelime.core.model.DeckTag.GENERAL))), db)
        assertTrue(Settings.bool(db, SettingKey.IS_PRO))
    }
}
