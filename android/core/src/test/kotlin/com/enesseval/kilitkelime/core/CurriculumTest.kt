package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.content.UnitPlacement
import com.enesseval.kilitkelime.core.crossword.CoursePuzzle
import com.enesseval.kilitkelime.core.crossword.CrosswordValidator
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.addingDays
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.query
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.OnboardingChoices
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.queries.DeckQueries
import com.enesseval.kilitkelime.core.review.QuickReview
import com.enesseval.kilitkelime.core.review.ReviewQuestion
import com.enesseval.kilitkelime.core.widgets.SampleContent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class CurriculumTest {
    private val clock = AppClock.fixed(Instant.parse("2026-10-13T07:20:00Z"), ZoneId.of("Europe/Istanbul"))
    private fun db(prefs: Preferences = Preferences(level = CEFRLevel.A1, enabledDecks = listOf(DeckID.A1))) = TestSupport.bundled(prefs)
    private fun ids(decks: List<DeckID>, db: JdbcSqlDb) = CardQueries.candidates(decks, db).map { it.cardID }

    private fun learn(fraction: Double, unit: String, db: JdbcSqlDb) {
        val cards = Curriculum.cards(unit, db)
        for (card in cards.take(Math.ceil(cards.size * fraction).toInt())) CardState(card.id, LearningState.LEARNED).save(db)
    }

    @Test fun importsTheA1Course() {
        val db = db()
        val units = Curriculum.units(CEFRLevel.A1, db)
        assertEquals(10, units.size)
        assertTrue(units.first().placement == UnitPlacement.FIRST && units.last().placement == UnitPlacement.LAST)
        assertTrue(units.all { it.stories.isNotEmpty() })
        val cafe = Curriculum.cards("a1-cafe", db)
        assertEquals("café", cafe.first().word)
        assertTrue(cafe.any { it.isPhrase && it.word == "Here you are." })
        assertTrue(Curriculum.cards("a1-home", db).any { it.id == "a1-table" })
        assertEquals(1, db.int("SELECT COUNT(*) FROM card WHERE id = 'a1-table'"))
        assertEquals(listOf("eski"), CardQueries.card("a1-old", db)!!.senses?.first()?.tr)
        assertEquals("Çoğulu: children.", CardQueries.card("a1-child", db)?.note)
    }

    @Test fun onlyStartedUnitsReachTheWidget() {
        val db = db()
        val core = Curriculum.cards("a1-core", db).map { it.id }.toSet()
        val cafeOnly = Curriculum.cards("a1-cafe", db).map { it.id }.toSet() - core
        assertEquals(core, ids(listOf(DeckID.A1), db).toSet())
        Curriculum.start("a1-cafe", db)
        assertEquals(core + cafeOnly, ids(listOf(DeckID.A1), db).toSet())
        assertEquals(listOf("a1-cafe", "a1-core"), Curriculum.progress(CEFRLevel.A1, db).filter { it.started }.map { it.unit.id }.sorted())
    }

    @Test fun startingAUnitSwitchesItsDeckOn() {
        val db = db(Preferences(level = CEFRLevel.B1))
        Curriculum.start("a1-family", db)
        assertTrue(DeckID.A1 in Preferences.load(db).enabledDecks)
    }

    @Test fun otherLevelsAreUnaffected() {
        assertEquals(109, CardQueries.candidates(DeckID.basicDecks, db(Preferences())).size)
    }

    @Test fun unitsComeInPlanOrder() {
        val state = Curriculum.state(db())!!
        assertEquals(listOf("a1-core", "a1-family", "a1-home"), state.units.take(3).map { it.id })
        assertEquals("a1-bridge", state.units.last().id)
        assertEquals("a1-core", state.currentID)
        assertNull(state.nextLevel)
    }

    @Test fun aNearlyLearnedUnitHandsOver() {
        val db = db()
        assertNull(Curriculum.advance(db))
        learn(0.85, "a1-core", db)
        assertEquals("a1-family", Curriculum.advance(db))
        val state = Curriculum.state(db)!!
        assertEquals("a1-family", state.currentID)
        assertEquals(listOf("a1-core", "a1-family"), state.units.filter { it.started }.map { it.id })
        assertNull(Curriculum.advance(db))
    }

    @Test fun aStartedUnitIsPickedUpBeforeANewOne() {
        val db = db()
        Curriculum.advance(db)
        Curriculum.start("a1-city", db)
        learn(0.85, "a1-core", db)
        assertEquals("a1-city", Curriculum.advance(db))
        learn(0.85, "a1-city", db)
        learn(0.85, "a1-family", db)
        assertEquals("a1-home", Curriculum.advance(db))
    }

    @Test fun theLearnerCanPickTheNextUnit() {
        val db = db()
        Curriculum.makeCurrent("a1-shopping", db)
        learn(0.85, "a1-core", db)
        Curriculum.advance(db)
        assertEquals("a1-shopping", Curriculum.state(db)?.currentID)
    }

    @Test fun importsTheA2Course() {
        val db = db(Preferences(level = CEFRLevel.A2, enabledDecks = listOf(DeckID.A2)))
        val state = Curriculum.state(db)!!
        assertEquals(12, state.units.size)
        assertEquals(listOf("a2-core", "a2-travel", "a2-work"), state.units.take(3).map { it.id })
        assertEquals("a2-bridge", state.units.last().id)
        assertEquals(PartOfSpeech.CONJUNCTION, CardQueries.card("a2-because", db)?.pos)
    }

    @Test fun anA2StarterGetsOnlyTheA2Course() {
        val db = db(Preferences())
        OnboardingChoices(CEFRLevel.A2).save(db)
        assertEquals(listOf(DeckID.A2), Preferences.load(db).enabledDecks)
    }

    @Test fun examDecksTakeCourseWordsWithoutStartingUnits() {
        val db = db(Preferences(level = CEFRLevel.A1, enabledDecks = listOf(DeckID.A1, DeckID.YDS), isPro = true))
        val yds = ids(listOf(DeckID.YDS), db)
        assertTrue(yds.any { it.endsWith("-claim") })
        assertTrue(yds.size > 60)
        assertTrue("exam-hamper" in yds)
        assertTrue(ids(listOf(DeckID.A1), db).all { it.startsWith("a1-") })
        Curriculum.switchLevel(CEFRLevel.C1, db)
        assertTrue(ids(listOf(DeckID.C1), db).none { it.startsWith("exam-") })
    }

    @Test fun switchingLevelLeavesOnlyTheNewCourse() {
        val db = db(Preferences(level = CEFRLevel.A1, enabledDecks = listOf(DeckID.A1, DeckID.YDS), isPro = true))
        val rng = SeededGenerator(1u)
        WidgetQueue.refill(db, clock, rng)
        Curriculum.switchLevel(CEFRLevel.B1, db)
        WidgetQueue.clearCurrentAndFuture(db, clock)
        WidgetQueue.refill(db, clock, rng)
        assertEquals(listOf(DeckID.B1, DeckID.YDS), Preferences.load(db).enabledDecks)
        assertEquals("b1-core", Curriculum.state(db)?.currentID)
        val card = CardQueries.card(WidgetQueue.current(db, clock)!!.cardID, db)!!
        assertTrue(card.level == CEFRLevel.B1 || card.id.startsWith("b") || card.id.startsWith("c") || card.id.startsWith("exam-"))
        assertTrue(ids(listOf(DeckID.B1), db).all { it.startsWith("b1-") })
    }

    @Test fun aFinishedA1OpensA2() {
        val db = db()
        for (unit in Curriculum.units(CEFRLevel.A1, db)) Curriculum.start(unit.id, db)
        Settings.set(db, SettingKey.CURRENT_UNIT, "a1-bridge")
        learn(0.85, "a1-bridge", db)
        assertEquals(CEFRLevel.A2, Curriculum.state(db)!!.nextLevel)
        Curriculum.moveOn(CEFRLevel.A2, db)
        val a2 = Curriculum.state(db)!!
        assertTrue(a2.level == CEFRLevel.A2 && a2.currentID == "a2-core")
        assertEquals(listOf(DeckID.A1, DeckID.A2), Preferences.load(db).enabledDecks)
    }

    @Test fun levelsWithoutUnitsHaveNoCourse() {
        val db = db(Preferences(level = CEFRLevel.C1))
        db.execute("DELETE FROM unit_card WHERE unit_id LIKE 'c1-%'")
        db.execute("DELETE FROM unit WHERE level = 'C1'")
        assertNull(Curriculum.state(db))
    }

    @Test fun phrasesStayOutOfWritingAndPuzzles() {
        val db = db()
        for (unit in Curriculum.units(CEFRLevel.A1, db)) Curriculum.start(unit.id, db)
        for (seed in 0uL until 30uL) {
            for (q in QuickReview.makeQuestions(db, SeededGenerator(seed))) {
                val kind = q.kind
                if (kind == ReviewQuestion.Kind.Write) assertTrue(q.card.isSingleWord)
                if (kind is ReviewQuestion.Kind.Meaning && q.card.isPhrase) {
                    val words = db.query(Sql("SELECT * FROM card WHERE word IN ") + Sql.list(kind.options), Card::from)
                    assertTrue(words.all { it.isPhrase })
                }
            }
        }
        assertFalse(CardQueries.card("a1-café", db)!!.isSingleWord)
    }

    @Test fun selfTestKeepsThePhraseShape() {
        assertEquals("Make" to " ________ __ ____.", SampleContent.phrase.selfTestPattern)
        assertEquals("r" to "________", SampleContent.reluctant.selfTestPattern)
    }

    @Test fun courseOffStaysOffAsUnitsStart() {
        val db = db(Preferences(level = CEFRLevel.A2, enabledDecks = listOf(DeckID.A1, DeckID.A2, DeckID.YDS)))
        DeckQueries.setCourse(false, db)
        assertEquals(listOf(DeckID.YDS), Preferences.load(db).enabledDecks)
        Curriculum.makeCurrent(Curriculum.units(CEFRLevel.A2, db).last().id, db)
        assertEquals(listOf(DeckID.YDS), Preferences.load(db).enabledDecks)
        assertFalse(DeckQueries.courseEnabled(db))
        DeckQueries.setCourse(true, db)
        assertEquals(setOf(DeckID.YDS, DeckID.A1, DeckID.A2), Preferences.load(db).enabledDecks.toSet())
    }
}

class CoursePuzzleTest {
    private val clock = AppClock.fixed(Instant.parse("2026-10-19T07:20:00Z"), ZoneId.of("Europe/Istanbul"))
    private fun db() = TestSupport.bundled(Preferences(level = CEFRLevel.A1, enabledDecks = listOf(DeckID.A1)))

    @Test fun usesTheCurrentUnitWithStrugglingWordsFirst() {
        val db = db()
        Curriculum.makeCurrent("a1-cafe", db)
        CardState("a1-mother", LearningState.STRUGGLING).save(db)
        val struggling = listOf("a1-coffee", "a1-milk", "a1-water")
        for (id in struggling) CardState(id, LearningState.STRUGGLING).save(db)
        val cafe = Curriculum.cards("a1-cafe", db).map { it.id }.toSet()
        for (offset in 0 until 20) {
            val puzzle = CoursePuzzle.daily(CEFRLevel.A1, clock.today.addingDays(offset), db)!!
            val ids = puzzle.entries.map { it.cardID }.toSet()
            assertTrue(cafe.containsAll(ids))
            assertTrue(CrosswordValidator.isValid(puzzle))
            assertTrue("day $offset: $ids", ids.containsAll(struggling))
        }
    }

    @Test fun todaysGridIsKeptWhileWordsChange() {
        val db = db()
        CoursePuzzle.keepToday(clock, db)
        val before = CoursePuzzle.daily(CEFRLevel.A1, clock.today, db)
        Curriculum.start("a1-home", db)
        CardState("a1-house", LearningState.STRUGGLING).save(db)
        CoursePuzzle.keepToday(clock, db)
        assertNotNull(before)
        assertEquals(before, CoursePuzzle.daily(CEFRLevel.A1, clock.today, db))
    }

    @Test fun levelsWithoutUnitsKeepNoGrid() {
        val db = db()
        db.execute("DELETE FROM unit_card WHERE unit_id LIKE 'c1-%'")
        db.execute("DELETE FROM unit WHERE level = 'C1'")
        Preferences(level = CEFRLevel.C1).save(db)
        CoursePuzzle.keepToday(clock, db)
        assertEquals(0, db.int("SELECT COUNT(*) FROM puzzle_progress"))
    }
}
