package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.content.ContentManifest
import com.enesseval.kilitkelime.core.content.ContentUpdater
import com.enesseval.kilitkelime.core.content.ImportResult
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckTag
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.Instant

class ContentImporterTest {
    private val reluctant = TestSupport.card("reluctant", CEFRLevel.B2, tr = listOf("isteksiz", "gönülsüz"))
    private val reliable = TestSupport.card("reliable", CEFRLevel.B1, tr = listOf("güvenilir"))
    private val borrow = TestSupport.card("borrow", CEFRLevel.A2, PartOfSpeech.VERB, listOf("ödünç almak"))
    private val general = listOf(DeckTag.GENERAL)

    @Test fun importsCardsAndDecks() {
        val db = TestSupport.database()
        val result = ContentImporter.importIfNeeded(TestSupport.cardsJSON(1, listOf(reluctant to listOf(DeckTag.GENERAL, DeckTag.YDS), reliable to general)), db)
        assertEquals(ImportResult.Imported(1, 2), result)
        assertEquals(2, db.int("SELECT COUNT(*) FROM card"))
        assertEquals(reluctant, CardQueries.card("b2-reluctant", db))
        assertEquals(1, db.int("SELECT COUNT(*) FROM card_deck WHERE deck = 'yds'"))
        assertEquals(1, Settings.int(db, SettingKey.CONTENT_VERSION))
    }

    @Test fun skipsWhenVersionUnchanged() {
        val db = TestSupport.database()
        val data = TestSupport.cardsJSON(3, listOf(reluctant to general))
        ContentImporter.importIfNeeded(data, db)
        assertEquals(ImportResult.UpToDate(3), ContentImporter.importIfNeeded(data, db))
    }

    @Test fun versionChangeUpsertsAndKeepsProgress() {
        val db = TestSupport.database()
        ContentImporter.importIfNeeded(TestSupport.cardsJSON(1, listOf(reluctant to listOf(DeckTag.GENERAL, DeckTag.YDS), reliable to general)), db)
        CardState("b2-reluctant", LearningState.STRUGGLING, 1, favorite = true).save(db)
        CardState("b1-reliable", LearningState.LEARNED).save(db)
        val edited = reluctant.copy(exampleEN = "He was reluctant to talk.")
        assertEquals(ImportResult.Imported(2, 2), ContentImporter.importIfNeeded(TestSupport.cardsJSON(2, listOf(edited to general, borrow to general)), db))
        assertEquals("He was reluctant to talk.", CardQueries.card("b2-reluctant", db)?.exampleEN)
        assertNotNull(CardQueries.card("a2-borrow", db))
        assertNull(CardQueries.card("b1-reliable", db))
        assertEquals(1, db.int("SELECT COUNT(*) FROM card_deck WHERE card_id = 'b2-reluctant'"))
        val state = CardState.fetch(db, "b2-reluctant")!!
        assertTrue(state.state == LearningState.STRUGGLING && state.correctStreak == 1 && state.favorite)
        assertEquals(LearningState.LEARNED, CardState.fetch(db, "b1-reliable")?.state)
    }

    @Test fun reportsProgressUpToOne() {
        val values = mutableListOf<Double>()
        ContentImporter.importIfNeeded(TestSupport.cardsJSON(1, (0 until 120).map { TestSupport.card("word$it") to general }), TestSupport.database()) { values += it }
        assertEquals(1.0, values.last(), 0.0)
        assertEquals(values.sorted(), values)
        assertTrue(values.size > 2)
    }

    @Test fun rejectsMalformedJSON() {
        try {
            ContentImporter.importIfNeeded("{\"cards\": []}", TestSupport.database())
            fail()
        } catch (_: kotlinx.serialization.SerializationException) {
        }
    }

    @Test fun importsBundledContent() {
        val file = ContentImporter.decode(TestSupport.bundledText)
        assertTrue(file.cards.size >= 150)
        assertEquals(file.cards.size, file.cards.map { it.id }.toSet().size)
        val db = TestSupport.database()
        ContentImporter.importIfNeeded(TestSupport.bundledText, db)
        assertEquals(file.cards.size, db.int("SELECT COUNT(*) FROM card"))
    }
}

class ContentUpdaterTest {
    private val reluctant = TestSupport.card("reluctant", CEFRLevel.B2)
    private val borrow = TestSupport.card("borrow", CEFRLevel.A2, PartOfSpeech.VERB)
    private val general = listOf(DeckTag.GENERAL)

    private fun manifest(data: String, version: Int, schema: Int = ContentUpdater.SCHEMA): ByteArray {
        val bytes = data.toByteArray()
        return Json.encodeToString(ContentManifest.serializer(), ContentManifest(version, schema, ContentUpdater.sha256(bytes), bytes.size)).toByteArray()
    }

    private fun server(manifest: ByteArray, cards: String): (String) -> ByteArray =
        { url -> if (url.endsWith("manifest.json")) manifest else cards.toByteArray() }

    private fun setUp(version: Int): JdbcSqlDb {
        val db = TestSupport.database()
        ContentImporter.importIfNeeded(TestSupport.cardsJSON(version, listOf(reluctant to general)), db)
        return db
    }

    @Test fun downloadsNewerContentAndPrefersItAtLaunch() {
        val db = setUp(1)
        val newer = TestSupport.cardsJSON(2, listOf(reluctant to general, borrow to general))
        var kept: ByteArray? = null
        val urls = mutableListOf<String>()
        val outcome = ContentUpdater.update(db, Instant.now(), { urls += it; server(manifest(newer, 2), newer)(it) }) { kept = it }
        assertEquals(ContentUpdater.Outcome.Updated(2), outcome)
        assertNotNull(CardQueries.card("a2-borrow", db))
        assertEquals(listOf(ContentUpdater.BASE_URL + "manifest.json", ContentUpdater.BASE_URL + "cards.json?v=2"), urls)
        val bundled = TestSupport.cardsJSON(1, listOf(reluctant to general))
        assertEquals(2, ContentUpdater.version(ContentUpdater.newest(bundled, kept!!.decodeToString())))
        val v3 = TestSupport.cardsJSON(3, listOf(reluctant to general))
        assertEquals(3, ContentUpdater.version(ContentUpdater.newest(v3, kept!!.decodeToString())))
    }

    @Test fun checksAtMostEverySixHours() {
        val db = setUp(1)
        val same = TestSupport.cardsJSON(1, listOf(reluctant to general))
        val fetch = server(manifest(same, 1), same)
        val now = Instant.now()
        assertEquals(ContentUpdater.Outcome.UpToDate(1), ContentUpdater.update(db, now, fetch) {})
        assertEquals(ContentUpdater.Outcome.Skipped, ContentUpdater.update(db, now.plusSeconds(3600), fetch) {})
        assertEquals(ContentUpdater.Outcome.UpToDate(1), ContentUpdater.update(db, now.plusSeconds(7 * 3600), fetch) {})
    }

    @Test fun rejectsATamperedFile() {
        val db = setUp(1)
        val newer = TestSupport.cardsJSON(2, listOf(borrow to general))
        val other = TestSupport.cardsJSON(2, listOf(reluctant to listOf(DeckTag.YDS)))
        var kept = false
        try {
            ContentUpdater.update(db, Instant.now(), server(manifest(newer, 2), other)) { kept = true }
            fail()
        } catch (e: ContentUpdater.UpdateException) {
            assertEquals("checksumMismatch", e.message)
        }
        assertEquals(1, Settings.int(db, SettingKey.CONTENT_VERSION))
        assertTrue(!kept)
    }

    @Test fun skipsContentForANewerAppVersion() {
        val db = setUp(1)
        val newer = TestSupport.cardsJSON(2, listOf(borrow to general))
        assertEquals(ContentUpdater.Outcome.UpToDate(1), ContentUpdater.update(db, Instant.now(), server(manifest(newer, 2, ContentUpdater.SCHEMA + 1), newer)) {})
    }

    @Test fun olderContentNeverReplacesNewer() {
        val db = setUp(2)
        assertEquals(ImportResult.UpToDate(1), ContentImporter.importIfNeeded(TestSupport.cardsJSON(1, listOf(borrow to general)), db))
        assertNotNull(CardQueries.card("b2-reluctant", db))
    }
}
