package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.model.Card
import java.time.Instant

/** One of the learner's own lists as the account keeps it. */
data class RemoteList(
    val id: String,
    val title: String,
    val visibility: ListVisibility,
    val cards: List<Card>,
    val updatedAt: Instant,
)

/**
 * Two-way sync of own lists with the account (port of `ListSync.swift`): the later change wins,
 * deletions travel as tombstones, lists saved from Keşfet or a file stay on the device.
 */
object ListSync {
    fun pendingUploads(db: SqlDb): List<RemoteList> =
        db.query("SELECT * FROM user_list WHERE imported = 0", emptyList(), UserList::from)
            .filter { it.needsUpload }
            .map { RemoteList(it.id, it.title, it.visibility, UserLists.cards(it.id, db), it.updatedAt ?: it.createdAt) }

    fun pendingDeletions(db: SqlDb): List<String> = db.strings("SELECT id FROM user_list_deleted")

    fun deletionSent(id: String, db: SqlDb) = db.execute("DELETE FROM user_list_deleted WHERE id = ?", listOf(id))

    fun uploaded(id: String, serverTime: Instant, db: SqlDb) =
        db.execute("UPDATE user_list SET synced_at = ?, updated_at = ? WHERE id = ?", listOf(serverTime, serverTime, id))

    /** Applies the account's lists; returns whether anything changed. */
    fun merge(remote: List<RemoteList>, db: SqlDb): Boolean {
        var changed = false
        val deleted = pendingDeletions(db).toSet()
        val remoteIDs = remote.map { it.id }.toSet()
        for (item in remote) {
            if (item.id in deleted) continue
            val local = UserList.fetch(db, item.id)
            if (local != null) {
                if (local.needsUpload || item.updatedAt <= (local.syncedAt ?: Instant.MIN)) continue
                local.copy(title = item.title, visibility = item.visibility, updatedAt = item.updatedAt, syncedAt = item.updatedAt).update(db)
                replaceCards(item.id, item.cards, db)
            } else {
                UserList(item.id, item.title, item.updatedAt, enabled = true, imported = false,
                    visibility = item.visibility, updatedAt = item.updatedAt, syncedAt = item.updatedAt).insert(db)
                UserLists.insertCards(item.cards, item.id, keepCustomIDs = true, db = db)
            }
            changed = true
        }
        val gone = db.query("SELECT * FROM user_list WHERE imported = 0 AND synced_at IS NOT NULL", emptyList(), UserList::from)
            .filter { it.id !in remoteIDs && !it.needsUpload }
        for (list in gone) {
            val cards = UserLists.cardIDs(list.id, db)
            db.execute("DELETE FROM user_list_card WHERE list_id = ?", listOf(list.id))
            db.execute("DELETE FROM user_list WHERE id = ?", listOf(list.id))
            UserLists.removeOrphans(cards, db)
            changed = true
        }
        return changed
    }

    /** After signing out: lists stay but belong to no account. */
    fun detach(db: SqlDb) {
        db.execute("UPDATE user_list SET synced_at = NULL, visibility = 'private'")
        db.execute("DELETE FROM user_list_deleted")
    }

    private fun replaceCards(id: String, cards: List<Card>, db: SqlDb) {
        val old = UserLists.cardIDs(id, db)
        db.execute("DELETE FROM user_list_card WHERE list_id = ?", listOf(id))
        UserLists.insertCards(cards, id, keepCustomIDs = true, db = db)
        UserLists.removeOrphans(old, db)
    }
}
