package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.games.StreakSource
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.queries.DeckQueries
import com.enesseval.kilitkelime.core.queries.StatsQueries
import com.enesseval.kilitkelime.core.queries.WordFilter
import com.enesseval.kilitkelime.core.queries.WordKind
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.core.queries.WordSegment
import com.enesseval.kilitkelime.core.queries.WordSort
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class QueriesTest {
    private val istanbul = ZoneId.of("Europe/Istanbul")
    private val clock = AppClock.fixed(Instant.parse("2026-10-14T09:00:00Z"), istanbul)
    private fun clock(daysAgo: Int) = AppClock.fixed(clock.now.minusSeconds(daysAgo * 86_400L), istanbul)
    private val right = LearningEvent.Answered(true)
    private val wrong = LearningEvent.Answered(false)
    private fun db() = TestSupport.bundled()

    @Test fun weekStartsOnMonday() {
        assertEquals("2026-10-12", StatsQueries.weekStart(LocalDate.of(2026, 10, 14)).toString())
        assertEquals("2026-10-12", StatsQueries.weekStart(LocalDate.of(2026, 10, 12)).toString())
        assertEquals("2026-10-12", StatsQueries.weekStart(LocalDate.of(2026, 10, 18)).toString())
        assertEquals("2026-10-26", StatsQueries.weekStart(LocalDate.of(2026, 11, 1)).toString())
    }

    @Test fun weekStatsCountThisWeekOnly() {
        val db = db()
        LearningStore.record(right, "b1-curious", ReviewSource.QUICK_REVIEW, clock, db)
        LearningStore.record(LearningEvent.MarkedKnown, "b1-reliable", ReviewSource.WORD_DETAIL, clock(2), db)
        LearningStore.record(right, "b1-honest", ReviewSource.QUICK_REVIEW, clock(3), db)
        LearningStore.record(wrong, "b2-reluctant", ReviewSource.QUICK_REVIEW, clock, db)
        val stats = StatsQueries.week(db, clock)
        assertEquals(2, stats.learnedThisWeek)
        assertEquals(1, stats.strugglingNow)
        assertEquals(listOf("P", "S", "Ç", "P", "C", "C", "P"), stats.days.map { it.initial })
        assertEquals(listOf(false, false, true, false, false, false, false), stats.days.map { it.reviewed })
    }

    @Test fun examCountdown() {
        assertEquals(33, StatsQueries.daysUntilExam(LocalDate.of(2026, 11, 16), clock))
        assertEquals(0, StatsQueries.daysUntilExam(LocalDate.of(2026, 10, 14), clock))
        assertNull(StatsQueries.daysUntilExam(LocalDate.of(2026, 10, 1), clock))
        assertNull(StatsQueries.daysUntilExam(null, clock))
    }

    @Test fun onlyFinishedRoundsCountForTheStreak() {
        val db = db()
        assertEquals(0, StatsQueries.streak(db, clock))
        // Widget answers and word detail buttons do not count.
        LearningStore.record(right, "b1-curious", ReviewSource.WIDGET, clock(1), db)
        assertEquals(0, StatsQueries.streak(db, clock))
        for (daysAgo in listOf(1, 2, 3, 6)) LearningStore.markStudied(clock(daysAgo).today, StreakSource.QUICK_REVIEW, db)
        // Today is still open: yesterday's run of three counts.
        assertEquals(3, StatsQueries.streak(db, clock))
        assertTrue(LearningStore.markStudied(clock.today, StreakSource.MATCH, db))
        assertFalse(LearningStore.markStudied(clock.today, StreakSource.PUZZLE, db))
        assertEquals(4, StatsQueries.week(db, clock).streak)
        assertEquals(listOf("match"), db.strings("SELECT source FROM streak_day WHERE day = ?", listOf(clock.today)))
    }

    @Test fun weeklySummaryFollowsThePlan() {
        val db = db()
        val monday = LocalDate.of(2026, 10, 5) // last week, seen from Wednesday 14 October
        fun at(day: LocalDate) = AppClock.fixed(day.atTime(12, 0).atZone(istanbul).toInstant(), istanbul)
        // reluctant: missed twice, then learned in the week → word of the week.
        LearningStore.record(wrong, "b2-reluctant", ReviewSource.QUICK_REVIEW, at(monday), db)
        LearningStore.record(wrong, "b2-reluctant", ReviewSource.QUICK_REVIEW, at(monday.plusDays(1)), db)
        LearningStore.record(right, "b2-reluctant", ReviewSource.QUICK_REVIEW, at(monday.plusDays(2)), db)
        LearningStore.record(right, "b2-reluctant", ReviewSource.QUICK_REVIEW, at(monday.plusDays(3)), db)
        LearningStore.record(wrong, "b1-honest", ReviewSource.WIDGET, at(monday.plusDays(3)), db)
        db.execute("INSERT INTO widget_shown (slot_start, card_id) VALUES (?, 'a'), (?, 'b'), (?, 'c')",
            listOf(at(monday).now, at(monday.plusDays(6)).now, at(monday.plusDays(7)).now))
        val summary = StatsQueries.lastWeek(db, clock)
        assertEquals(monday, summary.weekStart)
        assertEquals(1, summary.learned)
        assertEquals(1, summary.struggling)
        assertEquals(2, summary.shown)
        assertEquals(50, summary.quickReviewAccuracy)
        assertEquals("b2-reluctant", summary.wordOfWeek?.id)
        assertNull(StatsQueries.weekly(db, clock, monday.minusDays(7)).quickReviewAccuracy)
    }

    @Test fun wordListSegmentsAndSearch() {
        val db = db()
        LearningStore.record(LearningEvent.MarkedStruggling, "b2-reluctant", ReviewSource.WORD_DETAIL, clock, db)
        LearningStore.record(LearningEvent.MarkedKnown, "b1-reliable", ReviewSource.WORD_DETAIL, clock, db)
        LearningStore.setFavorite(true, "b1-curious", db)
        assertEquals(listOf("b2-reluctant"), WordQueries.list(WordSegment.STRUGGLING, db).map { it.id })
        assertEquals(listOf("b1-reliable"), WordQueries.list(WordSegment.LEARNED, db).map { it.id })
        assertEquals(listOf("b1-curious"), WordQueries.list(WordSegment.FAVORITES, db).map { it.id })
        val all = WordQueries.list(WordSegment.ALL, db)
        val core = Curriculum.cards("b1-core", db).map { it.id }
        assertEquals(core.toSet() + setOf("b2-reluctant", "b1-reliable", "b1-curious"), all.map { it.id }.toSet())
        val words = all.map { it.card.word.lowercase() }
        assertEquals(words.sorted(), words)
        assertEquals(listOf("b2-reluctant"), WordQueries.list(WordSegment.ALL, db, search = "relu").map { it.id })
        assertTrue("b1-reliable" in WordQueries.list(WordSegment.ALL, db, search = "GÜVENİLİR").map { it.id })
        assertEquals(listOf("b2-reluctant"), WordQueries.list(WordSegment.ALL, db, search = "isteksiz").map { it.id })
        assertEquals(listOf("b1-curious"), WordQueries.list(WordSegment.ALL, db, search = "merakli").map { it.id })
        assertTrue(WordQueries.list(WordSegment.STRUGGLING, db, search = "curious").isEmpty())
        Curriculum.start("b1-career", db)
        val career = Curriculum.cards("b1-career", db).map { it.id }
        assertTrue(WordQueries.list(WordSegment.ALL, db).map { it.id }.containsAll(career))
    }

    @Test fun wordListFiltersAndSorts() {
        val db = db()
        LearningStore.record(wrong, "b2-reluctant", ReviewSource.QUICK_REVIEW, clock(1), db)
        LearningStore.record(wrong, "b2-reluctant", ReviewSource.QUICK_REVIEW, clock, db)
        LearningStore.record(wrong, "b1-honest", ReviewSource.QUICK_REVIEW, clock(1), db)
        assertEquals(listOf("b2-reluctant"), WordQueries.list(WordSegment.ALL, db, filter = WordFilter(levels = setOf(CEFRLevel.B2))).map { it.id })
        assertEquals(setOf("b2-reluctant", "b1-honest"), WordQueries.list(WordSegment.ALL, db, filter = WordFilter(states = setOf(LearningState.STRUGGLING))).map { it.id }.toSet())
        val verbs = WordQueries.list(WordSegment.ALL, db, filter = WordFilter(kinds = setOf(WordKind.VERB)))
        assertTrue(verbs.isNotEmpty() && verbs.all { it.card.pos == PartOfSpeech.VERB })
        val fresh = WordQueries.list(WordSegment.ALL, db, filter = WordFilter(states = setOf(LearningState.NEW)))
        assertTrue(fresh.isNotEmpty() && fresh.all { it.state == LearningState.NEW })
        assertEquals(listOf("b2-reluctant", "b1-honest"), WordQueries.list(WordSegment.ALL, db, sort = WordSort.MOST_MISSED).take(2).map { it.id })
        assertEquals("b2-reluctant", WordQueries.list(WordSegment.ALL, db, sort = WordSort.RECENTLY_STUDIED).first().id)
        val reverse = WordQueries.list(WordSegment.ALL, db, sort = WordSort.REVERSE_ALPHABETICAL).map { it.card.word.lowercase() }
        assertEquals(reverse.sortedDescending(), reverse)
        val byLevel = WordQueries.list(WordSegment.ALL, db, sort = WordSort.LEVEL).map { it.card.level }
        assertEquals(byLevel.sorted(), byLevel)
    }

    @Test fun wordItemDetails() {
        val db = db()
        val yds = WordQueries.item("b2-significant", db)!!
        assertEquals("YDS", yds.deckLabel)
        assertTrue(yds.state == LearningState.NEW && !yds.favorite)
        assertEquals("Genel", WordQueries.item("b1-curious", db)?.deckLabel)
        assertNull(WordQueries.item("missing", db))
    }

    @Test fun deckProgressAndToggles() {
        val db = db()
        LearningStore.record(LearningEvent.MarkedKnown, "b1-curious", ReviewSource.WORD_DETAIL, clock, db)
        val progress = DeckQueries.progress(db)
        val byID = progress.associateBy { it.deck }
        assertEquals(DeckID.entries, progress.map { it.deck })
        assertTrue(byID[DeckID.A2]?.total == 356 && byID[DeckID.B1]?.learned == 1)
        assertTrue(byID[DeckID.A1]?.total == 285 && byID[DeckID.A1]?.enabled == false)
        assertEquals(355, byID[DeckID.YDS]?.total)
        assertEquals(true, byID[DeckID.B1]?.enabled)
        DeckQueries.setEnabled(false, DeckID.A2, db)
        assertEquals(listOf(DeckID.B1), Preferences.load(db).enabledDecks)
        DeckQueries.setEnabled(true, DeckID.YDS, db)
        assertEquals(listOf(DeckID.B1, DeckID.YDS), Preferences.load(db).enabledDecks)
    }

    @Test fun normalizeIsTurkishAware() {
        assertEquals("isik", WordQueries.normalize(" IŞIK "))
        assertEquals("isik", WordQueries.normalize("ışık"))
        assertEquals("guvenilir", WordQueries.normalize("GÜVENİLİR"))
        assertFalse(WordQueries.normalize("İ").contains("̇"))
    }
}
