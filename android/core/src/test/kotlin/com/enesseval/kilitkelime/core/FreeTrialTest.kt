package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.learning.ProgressReset
import com.enesseval.kilitkelime.core.model.ArchiveQuota
import com.enesseval.kilitkelime.core.model.FreeTrial
import com.enesseval.kilitkelime.core.model.PaywallMoment
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** The 3-day reverse trial and the weekly archive quota (docs/V1_2_PLAN.md §2, SYNC 2026-11-14). */
class FreeTrialTest {
    private val hour = 3600_000L
    private val t0 = 1_800_000_000_000L

    @Test fun startsOnceAtFirstLaunch() {
        val db = TestSupport.database()
        assertFalse(FreeTrial.status(db, t0).started)
        assertTrue(FreeTrial.startIfNeeded(db, t0))
        assertFalse(FreeTrial.startIfNeeded(db, t0 + 5 * hour))
        val status = FreeTrial.status(db, t0 + 5 * hour)
        assertTrue(status.active)
        assertEquals(67 * hour, status.remainingMs)
    }

    @Test fun lastsSeventyTwoHours() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        assertTrue(FreeTrial.status(db, t0 + 72 * hour - 1).active)
        assertTrue(FreeTrial.isPro(db, t0 + 72 * hour - 1))
        assertFalse(FreeTrial.status(db, t0 + 72 * hour).active)
        assertFalse(FreeTrial.isPro(db, t0 + 72 * hour + 1))
        assertTrue(FreeTrial.status(db, t0 + 100 * hour).ended)
    }

    @Test fun daysLeftRoundsUp() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        assertEquals(3, FreeTrial.status(db, t0).daysLeft)
        assertEquals(3, FreeTrial.status(db, t0 + 1 * hour).daysLeft)
        assertEquals(2, FreeTrial.status(db, t0 + 25 * hour).daysLeft)
        assertEquals(1, FreeTrial.status(db, t0 + 71 * hour).daysLeft)
        assertEquals(0, FreeTrial.status(db, t0 + 72 * hour).daysLeft)
    }

    @Test fun settingTheClockBackDoesNotStretchTheTrial() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        assertFalse(FreeTrial.status(db, t0 + 80 * hour).active)
        // Clock moved back to day one: still over.
        assertFalse(FreeTrial.status(db, t0 + 2 * hour).active)
        assertFalse(FreeTrial.isPro(db, t0))
        // Within the trial, a step back does not give time back either.
        val other = TestSupport.database()
        FreeTrial.startIfNeeded(other, t0)
        assertEquals(46 * hour, FreeTrial.status(other, t0 + 26 * hour).remainingMs)
        assertEquals(46 * hour, FreeTrial.status(other, t0).remainingMs)
    }

    @Test fun reopeningKeepsTheStartAndPurchaseKeepsPro() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        FreeTrial.startIfNeeded(db, t0 + 90 * hour)
        assertFalse(FreeTrial.isPro(db, t0 + 90 * hour))
        Settings.setBool(db, SettingKey.PURCHASED, true)
        assertTrue(FreeTrial.isPro(db, t0 + 90 * hour))
    }

    @Test fun noOfferWhileTheTrialRuns() {
        val now = 1_800_000_000_000L
        // Plenty of study days, but Pro (the trial) is on: no moment paywall.
        assertFalse(PaywallMoment.shouldOffer(9, 0, 0, 0, now, isPro = true))
        assertTrue(PaywallMoment.shouldOffer(9, 0, 0, 0, now, isPro = false))
    }

    @Test fun summaryOnlyOnce() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        assertFalse(FreeTrial.summaryDue(db, t0 + 10 * hour))
        assertTrue(FreeTrial.summaryDue(db, t0 + 73 * hour))
        assertTrue(FreeTrial.takeEnded(db, t0 + 73 * hour))
        assertFalse(FreeTrial.takeEnded(db, t0 + 74 * hour))
        FreeTrial.markSummaryShown(db)
        assertFalse(FreeTrial.summaryDue(db, t0 + 75 * hour))
    }

    @Test fun noSummaryForABuyer() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        Settings.setBool(db, SettingKey.PURCHASED, true)
        assertFalse(FreeTrial.summaryDue(db, t0 + 100 * hour))
    }

    @Test fun summaryCountsWhatTheTrialUsed() {
        val db = TestSupport.database()
        val clock = com.enesseval.kilitkelime.core.dates.AppClock.fixed(java.time.Instant.ofEpochMilli(t0), java.time.ZoneId.of("UTC"))
        FreeTrial.startIfNeeded(db, t0)
        FreeTrial.noteArchive(db, LocalDate.of(2026, 11, 10), t0 + hour)
        FreeTrial.noteArchive(db, LocalDate.of(2026, 11, 10), t0 + 2 * hour)
        FreeTrial.noteArchive(db, LocalDate.of(2026, 11, 11), t0 + 3 * hour)
        FreeTrial.notePersonal(db, t0 + 4 * hour)
        // After the trial nothing is counted.
        FreeTrial.noteArchive(db, LocalDate.of(2026, 11, 12), t0 + 80 * hour)
        val summary = FreeTrial.summary(db, clock)
        assertEquals(2, summary.archivePuzzles)
        assertEquals(1, summary.personalPuzzles)
        assertEquals(null, summary.examPercent)
    }

    @Test fun progressResetKeepsTheTrial() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        ProgressReset.reset(db)
        assertTrue(FreeTrial.status(db, t0).started)
        assertEquals(t0.toString(), Settings.string(db, SettingKey.TRIAL_START))
    }

    // Archive quota: 2 a week, renewed on Monday, unlimited for Pro.
    private val monday = LocalDate.of(2026, 11, 9)

    @Test fun twoArchivePuzzlesAWeek() {
        val db = TestSupport.database()
        val today = monday.plusDays(2)
        assertEquals(2, ArchiveQuota.left(db, today, false))
        val a = monday.minusDays(3)
        val b = monday.minusDays(4)
        val c = monday.minusDays(5)
        assertTrue(ArchiveQuota.canOpen(db, today, a, false, false))
        ArchiveQuota.consume(db, today, a, false)
        ArchiveQuota.consume(db, today, a, false)
        assertEquals(1, ArchiveQuota.left(db, today, false))
        ArchiveQuota.consume(db, today, b, false)
        assertEquals(0, ArchiveQuota.left(db, today, false))
        assertFalse(ArchiveQuota.canOpen(db, today, c, false, false))
        // Ones already opened this week, and ones already played, open again for free.
        assertTrue(ArchiveQuota.canOpen(db, today, a, false, false))
        assertTrue(ArchiveQuota.canOpen(db, today, c, false, true))
    }

    @Test fun quotaRenewsOnMonday() {
        val db = TestSupport.database()
        val sunday = monday.plusDays(6)
        ArchiveQuota.consume(db, sunday, monday.minusDays(3), false)
        ArchiveQuota.consume(db, sunday, monday.minusDays(4), false)
        assertEquals(0, ArchiveQuota.left(db, sunday, false))
        assertEquals(2, ArchiveQuota.left(db, sunday.plusDays(1), false))
        assertEquals(0, ArchiveQuota.left(db, monday.plusDays(6), false))
        // Saturday before is still the old week.
        assertEquals(2, ArchiveQuota.left(db, monday.minusDays(1), false))
    }

    @Test fun proHasNoLimit() {
        val db = TestSupport.database()
        val today = monday
        for (i in 1..10) {
            assertTrue(ArchiveQuota.canOpen(db, today, today.minusDays(i.toLong()), true, false))
            ArchiveQuota.consume(db, today, today.minusDays(i.toLong()), true)
        }
        assertEquals(2, ArchiveQuota.left(db, today, false))
        assertEquals(Int.MAX_VALUE, ArchiveQuota.left(db, today, true))
    }

    @Test fun secondAndLaterOwnListsAreReadOnlyWithoutPro() {
        val db = TestSupport.database()
        val t = java.time.Instant.parse("2026-11-01T10:00:00Z")
        val first = com.enesseval.kilitkelime.core.learning.UserLists.create("Bir", true, db, t)
        val second = com.enesseval.kilitkelime.core.learning.UserLists.create("İki", true, db, t.plusSeconds(60))
        val third = com.enesseval.kilitkelime.core.learning.UserLists.create("Üç", true, db, t.plusSeconds(120))
        val lists = com.enesseval.kilitkelime.core.learning.UserLists
        assertFalse(lists.isReadOnly(first.id, false, db))
        assertTrue(lists.isReadOnly(second.id, false, db))
        assertTrue(lists.isReadOnly(third.id, false, db))
        // Pro (a purchase or the running trial) edits all of them; nothing was deleted.
        assertFalse(lists.isReadOnly(second.id, true, db))
        assertEquals(3, lists.summaries(db).size)
    }

    @Test fun cachedProStopsCountingOnceTheTrialLapses() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        Settings.setBool(db, SettingKey.IS_PRO, true) // the cache while the trial runs
        Settings.setBool(db, SettingKey.PURCHASED, false)
        assertTrue(com.enesseval.kilitkelime.core.model.Preferences.load(db, t0 + 71 * hour).isPro)
        // The app is never opened again: widgets read the preferences themselves.
        val lapsed = com.enesseval.kilitkelime.core.model.Preferences.load(db, t0 + 73 * hour)
        assertFalse(lapsed.isPro)
        assertEquals(com.enesseval.kilitkelime.core.model.RotationInterval.DEFAULT, lapsed.effectiveRotation)
        assertEquals(com.enesseval.kilitkelime.core.model.WidgetThemeID.PAPER, lapsed.copy(theme = com.enesseval.kilitkelime.core.model.WidgetThemeID.entries.first { it.isPro }).effectiveTheme)
        // A turned-back clock does not revive it once the later time was seen.
        FreeTrial.status(db, t0 + 80 * hour)
        assertFalse(com.enesseval.kilitkelime.core.model.Preferences.load(db, t0 + hour).isPro)
        assertEquals(t0 + 72 * hour, FreeTrial.endsAt(db))
    }

    @Test fun aPurchaseSurvivesAnUnreadableStoreAfterTheTrial() {
        // RevenueCat could not be read (offline, no cache): the last known purchase stays, no summary.
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        Settings.setBool(db, SettingKey.PURCHASED, true)
        Settings.setBool(db, SettingKey.IS_PRO, true)
        val later = t0 + 200 * hour
        assertTrue(FreeTrial.isPro(db, later))
        assertFalse(FreeTrial.summaryDue(db, later))
        assertFalse(FreeTrial.lapsed(db, later))
        assertTrue(com.enesseval.kilitkelime.core.model.Preferences.load(db, later).isPro)
        assertEquals(null, FreeTrial.endsAt(db))
    }

    @Test fun a11BuyerOpeningOfflineKeepsPro() {
        // 1.1 had only the purchase in the Pro cache and no PURCHASED record.
        val db = TestSupport.database()
        Settings.setBool(db, SettingKey.IS_PRO, true)
        assertEquals(null, Settings.string(db, SettingKey.PURCHASED))
        FreeTrial.migratePurchase(db)
        FreeTrial.startIfNeeded(db, t0)
        assertTrue(Settings.bool(db, SettingKey.PURCHASED))
        val later = t0 + 100 * hour
        assertTrue(FreeTrial.isPro(db, later))
        assertFalse(FreeTrial.summaryDue(db, later))
        assertFalse(FreeTrial.dropLapsedPro(db, later))
        assertTrue(Settings.bool(db, SettingKey.IS_PRO))
        // A free 1.1 user stays free; an existing record is never overwritten.
        val free = TestSupport.database()
        FreeTrial.migratePurchase(free)
        assertFalse(Settings.bool(free, SettingKey.PURCHASED))
        Settings.setBool(free, SettingKey.IS_PRO, true)
        FreeTrial.migratePurchase(free)
        assertFalse(Settings.bool(free, SettingKey.PURCHASED))
    }

    @Test fun lapsedTrialDropsTheCachedProOnceSoTheQueueCanBeRebuilt() {
        val db = TestSupport.database()
        FreeTrial.startIfNeeded(db, t0)
        Settings.setBool(db, SettingKey.PURCHASED, false)
        Settings.setBool(db, SettingKey.IS_PRO, true)
        assertFalse(FreeTrial.dropLapsedPro(db, t0 + 10 * hour))
        assertTrue(FreeTrial.dropLapsedPro(db, t0 + 73 * hour))
        assertFalse(Settings.bool(db, SettingKey.IS_PRO))
        assertFalse(FreeTrial.dropLapsedPro(db, t0 + 74 * hour))
    }

    @Test fun lockedListsCannotBeExportedWithoutPro() {
        val db = TestSupport.database()
        val lists = com.enesseval.kilitkelime.core.learning.UserLists
        val t = java.time.Instant.parse("2026-11-01T10:00:00Z")
        val first = lists.create("Bir", true, db, t)
        val second = lists.create("İki", true, db, t.plusSeconds(60))
        assertFalse(lists.canExport(first.id, false, db))
        assertFalse(lists.canExport(second.id, false, db))
        assertTrue(lists.canExport(second.id, true, db))
    }

    @Test fun nextFreeGameIsTheFirstNotPlayedToday() {
        val db = TestSupport.bundled()
        val clock = com.enesseval.kilitkelime.core.dates.AppClock.fixed(java.time.Instant.parse("2026-11-14T10:00:00Z"), java.time.ZoneId.of("UTC"))
        assertEquals(Game.WORD_HUNT, com.enesseval.kilitkelime.core.games.FreeGames.next(db, clock))
        com.enesseval.kilitkelime.core.games.GameResults.record(Game.WORD_HUNT, 5, 6, 90, clock, db)
        assertEquals(Game.MATCH, com.enesseval.kilitkelime.core.games.FreeGames.next(db, clock))
        com.enesseval.kilitkelime.core.games.GameResults.record(Game.MATCH, 7, 7, 60, clock, db)
        assertEquals(Game.SENTENCE, com.enesseval.kilitkelime.core.games.FreeGames.next(db, clock))
        com.enesseval.kilitkelime.core.games.GameResults.record(Game.SENTENCE, 4, 5, 80, clock, db)
        com.enesseval.kilitkelime.core.games.GameResults.record(Game.GAP_FILL, 9, 10, 60, clock, db)
        // All played today: the suggestion starts over.
        assertEquals(Game.WORD_HUNT, com.enesseval.kilitkelime.core.games.FreeGames.next(db, clock))
    }
}
