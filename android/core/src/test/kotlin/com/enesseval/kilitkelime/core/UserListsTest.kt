package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.ListSync
import com.enesseval.kilitkelime.core.learning.ListVisibility
import com.enesseval.kilitkelime.core.learning.RemoteList
import com.enesseval.kilitkelime.core.learning.SharedList
import com.enesseval.kilitkelime.core.learning.UserListException
import com.enesseval.kilitkelime.core.learning.UserListException.Reason
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.core.queries.WordSegment
import com.enesseval.kilitkelime.core.widgets.SampleContent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.Instant

private fun expectReason(reason: Reason, block: () -> Unit) {
    try {
        block()
        fail("expected $reason")
    } catch (e: UserListException) {
        assertEquals(reason, e.reason)
    }
}

private fun db() = TestSupport.bundled(Preferences(level = CEFRLevel.A1, enabledDecks = listOf(DeckID.A1)))

class UserListsTest {
    @Test fun freeUsersHaveOneListAndImportsDoNotCount() {
        val db = db()
        UserLists.create("  İş  ", false, db)
        expectReason(Reason.LIMIT_REACHED) { UserLists.create("İkinci", false, db) }
        expectReason(Reason.EMPTY_TITLE) { UserLists.create(" ", true, db) }
        UserLists.create("Pro ile", true, db, Instant.now().plusSeconds(1))
        UserLists.import(SharedList(title = "Arkadaştan", cards = listOf(SampleContent.happy)), db, now = Instant.now().plusSeconds(2))
        assertEquals(listOf("İş", "Pro ile", "Arkadaştan"), UserLists.summaries(db).map { it.list.title })
    }

    @Test fun addsAppWordsAndOwnWords() {
        val db = db()
        val list = UserLists.create("Gezi", false, db)
        UserLists.add("a1-coffee", list.id, db)
        expectReason(Reason.DUPLICATE_WORD) { UserLists.add("a1-coffee", list.id, db) }
        val own = UserLists.addCustom("boarding pass", "biniş kartı, uçuş kartı", PartOfSpeech.NOUN, CEFRLevel.A1, list.id, db)
        assertTrue(own.id.startsWith(UserLists.CUSTOM_PREFIX))
        assertEquals(PartOfSpeech.PHRASE, own.pos)
        assertEquals(listOf("biniş kartı", "uçuş kartı"), own.tr)
        expectReason(Reason.EMPTY_WORD) { UserLists.addCustom("gate", " ", PartOfSpeech.NOUN, CEFRLevel.A1, list.id, db) }
        val cards = UserLists.cards(list.id, db)
        assertEquals(listOf("coffee", "boarding pass"), cards.map { it.word })
        UserLists.remove(cards[1].id, list.id, db)
        assertNull(CardQueries.card(cards[1].id, db))
        UserLists.delete(list.id, db)
        assertTrue(CardQueries.card("a1-coffee", db) != null)
        assertTrue(UserLists.summaries(db).isEmpty())
    }

    @Test fun contentUpdatesKeepOwnWords() {
        val db = db()
        val list = UserLists.create("Benim", false, db)
        val own = UserLists.addCustom("serendipity", "mutlu tesadüf", PartOfSpeech.NOUN, CEFRLevel.A1, list.id, db)
        db.transaction { com.enesseval.kilitkelime.core.content.ContentImporterAccess.apply(TestSupport.bundledText, db) }
        assertEquals("serendipity", CardQueries.card(own.id, db)?.word)
    }

    @Test fun listsFeedTheWidgetAndQuickReview() {
        val db = db()
        val list = UserLists.create("B2", false, db)
        UserLists.add("b2-reluctant", list.id, db)
        UserLists.addCustom("zeal", "şevk", PartOfSpeech.NOUN, CEFRLevel.A1, list.id, db)
        val ids = CardQueries.candidates(listOf(DeckID.A1), db).map { it.cardID }
        assertTrue("b2-reluctant" in ids)
        assertTrue(ids.any { it.startsWith(UserLists.CUSTOM_PREFIX) })
        Preferences.load(db).copy(enabledDecks = emptyList()).save(db)
        assertEquals(2, CardQueries.candidates(Preferences.load(db).entitledDecks, db).size)
        UserLists.setEnabled(false, list.id, db)
        assertFalse("b2-reluctant" in CardQueries.candidates(listOf(DeckID.A1), db).map { it.cardID })
    }

    @Test fun sharedListsRoundTrip() {
        val db = db()
        val list = UserLists.create("Paylaş", true, db)
        UserLists.add("a1-happy", list.id, db)
        UserLists.addCustom("zeal", "şevk", PartOfSpeech.NOUN, CEFRLevel.A1, list.id, db, exampleEN = "Full of zeal.")
        val shared = UserLists.export(list.id, db)!!
        val decoded = SharedList.decode(shared.encoded())
        assertEquals(shared, decoded)
        val other = db()
        val imported = UserLists.import(decoded, other)
        val cards = UserLists.cards(imported.id, other)
        assertTrue(imported.imported && imported.title == "Paylaş")
        assertEquals(listOf("happy", "zeal"), cards.map { it.word })
        assertEquals("a1-happy", cards[0].id)
        assertTrue(cards[1].id.startsWith(UserLists.CUSTOM_PREFIX) && cards[1].exampleEN == "Full of zeal.")
    }

    @Test fun listWordsAreInTumuAndSuggestionsFindAppWords() {
        val db = db()
        val list = UserLists.create("Kelimeler", false, db)
        UserLists.add("c1-mitigate", list.id, db)
        assertTrue(WordQueries.list(WordSegment.ALL, db).any { it.id == "c1-mitigate" })
        assertEquals("b2-reluctant", UserLists.suggestions("relu", db).first().id)
        assertTrue(UserLists.suggestions("mutlu", db).any { it.id == "a1-happy" })
        assertTrue(UserLists.suggestions("MUTLU", db).any { it.id == "a1-happy" })
    }
}

class ListSyncTest {
    @Test fun uploadsOwnListsUntilTheyMatchTheServer() {
        val db = db()
        val list = UserLists.create("Gezi", false, db)
        UserLists.add("a1-coffee", list.id, db)
        UserLists.addCustom("boarding pass", "biniş kartı", PartOfSpeech.NOUN, CEFRLevel.A1, list.id, db)
        UserLists.import(SharedList(title = "Arkadaştan", cards = listOf(SampleContent.happy)), db)
        val pending = ListSync.pendingUploads(db)
        assertEquals(listOf(list.id), pending.map { it.id })
        assertEquals(2, pending[0].cards.size)
        ListSync.uploaded(list.id, Instant.now().plusSeconds(5), db)
        assertTrue(ListSync.pendingUploads(db).isEmpty())
        UserLists.setVisibility(ListVisibility.PUBLIC, list.id, db)
        db.execute("UPDATE user_list SET updated_at = ? WHERE id = ?", listOf(Instant.now().plusSeconds(10), list.id))
        assertEquals(ListVisibility.PUBLIC, ListSync.pendingUploads(db).first().visibility)
    }

    @Test fun mergeAddsReplacesAndDeletes() {
        val db = db()
        val t0 = Instant.ofEpochSecond(1_800_000_000)
        val own = Card("user-abc", "gate", PartOfSpeech.NOUN, CEFRLevel.A1, listOf("kapı"), "", "")
        val remote = RemoteList("11111111-1111-1111-1111-111111111111", "Uçuş", ListVisibility.LINK, listOf(own, SampleContent.happy), t0)
        ListSync.merge(listOf(remote), db)
        assertTrue("user-abc" in UserLists.cards(remote.id, db).map { it.id })
        assertTrue(ListSync.pendingUploads(db).isEmpty())
        ListSync.merge(listOf(remote.copy(title = "Uçuş 2", cards = listOf(own), updatedAt = t0.plusSeconds(60))), db)
        assertEquals("Uçuş 2", UserLists.list(remote.id, db)?.title)
        assertEquals(1, UserLists.cards(remote.id, db).size)
        ListSync.merge(emptyList(), db)
        assertNull(UserLists.list(remote.id, db))
        assertEquals(0, db.int("SELECT COUNT(*) FROM card WHERE id = 'user-abc'"))
    }

    @Test fun deletingASyncedListQueuesTheServerDelete() {
        val db = db()
        val list = UserLists.create("Gezi", false, db)
        ListSync.uploaded(list.id, Instant.now(), db)
        UserLists.delete(list.id, db)
        assertEquals(listOf(list.id), ListSync.pendingDeletions(db))
        ListSync.merge(listOf(RemoteList(list.id, "Gezi", ListVisibility.PRIVATE, emptyList(), Instant.now().plusSeconds(60))), db)
        assertNull(UserLists.list(list.id, db))
    }

    @Test fun detachMakesListsPrivateAndUnsynced() {
        val db = db()
        val list = UserLists.create("Gezi", false, db)
        UserLists.setVisibility(ListVisibility.PUBLIC, list.id, db)
        ListSync.uploaded(list.id, Instant.now().plusSeconds(5), db)
        ListSync.detach(db)
        val after = UserLists.list(list.id, db)!!
        assertTrue(after.syncedAt == null && after.visibility == ListVisibility.PRIVATE && after.needsUpload)
    }
}
