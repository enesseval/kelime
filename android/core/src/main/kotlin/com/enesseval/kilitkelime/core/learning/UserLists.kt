package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.db.RawValue
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.SqlRow
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.longOrNull
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.queries.WordQueries
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

enum class ListVisibility(override val raw: String) : RawValue {
    PRIVATE("private"), LINK("link"), PUBLIC("public");

    companion object {
        fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } ?: PRIVATE
    }
}

/** One of the learner's own word lists. */
data class UserList(
    val id: String,
    val title: String,
    val createdAt: Instant,
    /** On the lock screen and in Quick Review. */
    val enabled: Boolean,
    /** Came from a file or Keşfet: not counted towards the free limit, not synced. */
    val imported: Boolean,
    val visibility: ListVisibility = ListVisibility.PRIVATE,
    val updatedAt: Instant? = null,
    val syncedAt: Instant? = null,
    val sourceID: String? = null,
) {
    /** Changed here since it last matched the server. */
    val needsUpload: Boolean
        get() {
            if (imported) return false
            val synced = syncedAt ?: return true
            return (updatedAt ?: Instant.MIN) > synced
        }

    fun insert(db: SqlDb) {
        db.execute(
            """INSERT INTO user_list (id, title, created_at, enabled, imported, visibility, updated_at, synced_at, source_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            listOf(id, title, createdAt, enabled, imported, visibility, updatedAt, syncedAt, sourceID),
        )
    }

    fun update(db: SqlDb) {
        db.execute(
            """UPDATE user_list SET title = ?, created_at = ?, enabled = ?, imported = ?, visibility = ?,
               updated_at = ?, synced_at = ?, source_id = ? WHERE id = ?""",
            listOf(title, createdAt, enabled, imported, visibility, updatedAt, syncedAt, sourceID, id),
        )
    }

    companion object {
        fun from(row: SqlRow) = UserList(
            id = row.requireString("id"),
            title = row.requireString("title"),
            createdAt = row.instant("created_at") ?: Instant.EPOCH,
            enabled = row.bool("enabled"),
            imported = row.bool("imported"),
            visibility = ListVisibility.fromRaw(row.string("visibility")),
            updatedAt = row.instant("updated_at"),
            syncedAt = row.instant("synced_at"),
            sourceID = row.string("source_id"),
        )

        fun fetch(db: SqlDb, id: String): UserList? =
            db.query("SELECT * FROM user_list WHERE id = ?", listOf(id), ::from).firstOrNull()
    }
}

/** A list with its counts, for the Listeler screen. */
data class UserListSummary(val list: UserList, val total: Int, val learned: Int) {
    val id: String get() = list.id
    val fraction: Double get() = if (total == 0) 0.0 else learned.toDouble() / total
}

/** A list as it travels in a shared file (`.kelimelist`). */
@Serializable
data class SharedList(val format: Int = 1, val title: String, val cards: List<Card>) {
    fun encoded(): String = Json.encodeToString(serializer(), this)

    companion object {
        const val FILE_EXTENSION = "kelimelist"
        fun decode(text: String): SharedList = Json.decodeFromString(serializer(), text)
    }
}

class UserListException(val reason: Reason) : Exception(reason.name) {
    enum class Reason { LIMIT_REACHED, EMPTY_TITLE, EMPTY_WORD, DUPLICATE_WORD, UNREADABLE_FILE }
}

/** The learner's own lists (port of `UserLists.swift`). */
object UserLists {
    const val CUSTOM_PREFIX = "user-"
    const val FREE_LIMIT = 1
    const val MAX_TITLE = 40

    /** SQL condition: the card is in a list that is on. */
    val enabledListsCondition = Sql(
        "EXISTS (SELECT 1 FROM user_list_card ulc JOIN user_list ul ON ul.id = ulc.list_id " +
            "WHERE ulc.card_id = c.id AND ul.enabled = 1)",
    )

    fun summaries(db: SqlDb): List<UserListSummary> =
        db.query("SELECT * FROM user_list ORDER BY created_at", emptyList(), UserList::from).map { list ->
            db.query(
                """SELECT COUNT(*) AS total, SUM(CASE WHEN s.state = 'learned' THEN 1 ELSE 0 END) AS learned
                   FROM user_list_card l LEFT JOIN card_state s ON s.card_id = l.card_id WHERE l.list_id = ?""",
                listOf(list.id),
            ) { UserListSummary(list, it.int("total") ?: 0, it.int("learned") ?: 0) }.first()
        }

    fun list(id: String, db: SqlDb): UserList? = UserList.fetch(db, id)

    /**
     * After the free trial the learner's second and later own lists stay but cannot be changed
     * (docs/V1_2_PLAN.md §2): nothing is deleted. Pro, imported lists and the first own list are editable.
     */
    fun isReadOnly(id: String, isPro: Boolean, db: SqlDb): Boolean {
        if (isPro) return false
        val own = db.query("SELECT id FROM user_list WHERE imported = 0 ORDER BY created_at, id") { it.string("id") }
        val index = own.indexOf(id)
        return index >= FREE_LIMIT
    }

    /**
     * "Dosya olarak gönder" is Pro. A locked (read-only) list is never Pro-editable without Pro, so a free
     * learner cannot export it and import it back as an editable "imported" copy.
     */
    fun canExport(id: String, isPro: Boolean, db: SqlDb): Boolean = isPro && !isReadOnly(id, isPro, db)

    fun canCreate(isPro: Boolean, db: SqlDb): Boolean =
        isPro || db.int("SELECT COUNT(*) FROM user_list WHERE imported = 0") < FREE_LIMIT

    fun create(title: String, isPro: Boolean, db: SqlDb, now: Instant = Instant.now()): UserList {
        val clean = clean(title)
        if (!canCreate(isPro, db)) throw UserListException(UserListException.Reason.LIMIT_REACHED)
        val list = UserList(UUID.randomUUID().toString().lowercase(), clean, now, enabled = true, imported = false, updatedAt = now)
        list.insert(db)
        return list
    }

    fun rename(id: String, title: String, db: SqlDb, now: Instant = Instant.now()) {
        val list = UserList.fetch(db, id) ?: return
        list.copy(title = clean(title), updatedAt = now).update(db)
    }

    fun setVisibility(visibility: ListVisibility, id: String, db: SqlDb, now: Instant = Instant.now()) {
        val list = UserList.fetch(db, id) ?: return
        if (list.visibility == visibility) return
        list.copy(visibility = visibility, updatedAt = now).update(db)
    }

    internal fun touch(id: String, db: SqlDb, now: Instant = Instant.now()) {
        db.execute("UPDATE user_list SET updated_at = ? WHERE id = ?", listOf(now, id))
    }

    fun setEnabled(enabled: Boolean, id: String, db: SqlDb) {
        db.execute("UPDATE user_list SET enabled = ? WHERE id = ?", listOf(enabled, id))
    }

    /** Deletes the list; own words in no other list go too. */
    fun delete(id: String, db: SqlDb) {
        val cards = cardIDs(id, db)
        if (UserList.fetch(db, id)?.syncedAt != null) {
            db.execute("INSERT OR IGNORE INTO user_list_deleted (id) VALUES (?)", listOf(id))
        }
        db.execute("DELETE FROM user_list_card WHERE list_id = ?", listOf(id))
        db.execute("DELETE FROM user_list WHERE id = ?", listOf(id))
        removeOrphans(cards, db)
    }

    fun cards(id: String, db: SqlDb): List<Card> = db.query(
        "SELECT c.* FROM card c JOIN user_list_card l ON l.card_id = c.id WHERE l.list_id = ? ORDER BY l.position",
        listOf(id), Card::from,
    )

    internal fun cardIDs(id: String, db: SqlDb): List<String> =
        db.strings("SELECT card_id FROM user_list_card WHERE list_id = ? ORDER BY position", listOf(id))

    private fun cardExists(id: String, db: SqlDb) = db.int("SELECT COUNT(*) FROM card WHERE id = ?", listOf(id)) > 0

    /** Adds an existing card to the list. */
    fun add(cardID: String, id: String, db: SqlDb) {
        if (!cardExists(cardID, db)) return
        if (db.int("SELECT COUNT(*) FROM user_list_card WHERE list_id = ? AND card_id = ?", listOf(id, cardID)) > 0) {
            throw UserListException(UserListException.Reason.DUPLICATE_WORD)
        }
        val next = (db.longOrNull("SELECT MAX(position) FROM user_list_card WHERE list_id = ?", listOf(id)) ?: -1L) + 1
        db.execute("INSERT INTO user_list_card (list_id, card_id, position) VALUES (?, ?, ?)", listOf(id, cardID, next))
        touch(id, db)
    }

    /** Adds a word the learner typed. [level] only picks wrong quiz options. */
    fun addCustom(
        word: String, meaning: String, pos: PartOfSpeech, level: CEFRLevel, id: String, db: SqlDb,
        exampleEN: String = "", exampleTR: String = "",
    ): Card {
        val w = word.trim()
        val meanings = meaning.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        if (w.isEmpty() || meanings.isEmpty()) throw UserListException(UserListException.Reason.EMPTY_WORD)
        if (cards(id, db).any { it.word.lowercase() == w.lowercase() }) throw UserListException(UserListException.Reason.DUPLICATE_WORD)
        val card = Card(
            id = CUSTOM_PREFIX + UUID.randomUUID().toString().uppercase(),
            word = w,
            pos = if (w.contains(" ") && pos != PartOfSpeech.PHRASE) PartOfSpeech.PHRASE else pos,
            level = level,
            tr = meanings.take(3),
            exampleEN = exampleEN.trim(),
            exampleTR = exampleTR.trim(),
        )
        ContentImporter.insert(card, db)
        add(card.id, id, db)
        return card
    }

    fun remove(cardID: String, id: String, db: SqlDb) {
        db.execute("DELETE FROM user_list_card WHERE list_id = ? AND card_id = ?", listOf(id, cardID))
        touch(id, db)
        removeOrphans(listOf(cardID), db)
    }

    fun export(id: String, db: SqlDb): SharedList? {
        val list = UserList.fetch(db, id) ?: return null
        return SharedList(title = list.title, cards = cards(id, db))
    }

    /** Adds a shared list; known words link to their cards, others become own words. */
    fun import(shared: SharedList, db: SqlDb, sourceID: String? = null, now: Instant = Instant.now()): UserList {
        val title = runCatching { clean(shared.title) }.getOrDefault("Paylaşılan liste")
        val list = UserList(UUID.randomUUID().toString().lowercase(), title, now, enabled = true, imported = true, sourceID = sourceID)
        list.insert(db)
        insertCards(shared.cards, list.id, keepCustomIDs = false, db = db)
        return list
    }

    fun savedCopy(sourceID: String, db: SqlDb): UserList? =
        db.query("SELECT * FROM user_list WHERE source_id = ? LIMIT 1", listOf(sourceID), UserList::from).firstOrNull()

    internal fun insertCards(cards: List<Card>, listID: String, keepCustomIDs: Boolean, db: SqlDb) {
        var position = 0
        val seen = mutableSetOf<String>()
        for (card in cards) {
            if (!seen.add(card.word.lowercase())) continue
            val id = when {
                !card.id.startsWith(CUSTOM_PREFIX) && cardExists(card.id, db) -> card.id
                keepCustomIDs && card.id.startsWith(CUSTOM_PREFIX) -> {
                    ContentImporter.upsert(card.copy(tr = card.tr.take(3)), db)
                    card.id
                }
                else -> {
                    val copy = card.copy(id = CUSTOM_PREFIX + UUID.randomUUID().toString().uppercase(), tr = card.tr.take(3))
                    ContentImporter.insert(copy, db)
                    copy.id
                }
            }
            db.execute("INSERT INTO user_list_card (list_id, card_id, position) VALUES (?, ?, ?)", listOf(listID, id, position))
            position += 1
        }
    }

    /** Course and exam words matching [search], for adding to a list. */
    fun suggestions(search: String, db: SqlDb, limit: Int = 30): List<Card> {
        val needle = WordQueries.normalize(search)
        if (needle.isEmpty()) return emptyList()
        val cards = db.query("SELECT * FROM card WHERE id NOT LIKE ? ORDER BY word", listOf("$CUSTOM_PREFIX%"), Card::from)
        val starts = cards.filter { WordQueries.normalize(it.word).startsWith(needle) }
        val rest = cards.filter { card ->
            val w = WordQueries.normalize(card.word)
            !w.startsWith(needle) && (w.contains(needle) || WordQueries.normalize(card.meaning).contains(needle))
        }
        return (starts + rest).take(limit)
    }

    fun hasEnabledLists(db: SqlDb): Boolean = db.int(
        "SELECT EXISTS (SELECT 1 FROM user_list ul JOIN user_list_card c ON c.list_id = ul.id WHERE ul.enabled = 1)",
    ) != 0

    private fun clean(title: String): String {
        val t = title.trim()
        if (t.isEmpty()) throw UserListException(UserListException.Reason.EMPTY_TITLE)
        return t.take(MAX_TITLE)
    }

    internal fun removeOrphans(cardIDs: List<String>, db: SqlDb) {
        for (id in cardIDs.filter { it.startsWith(CUSTOM_PREFIX) }) {
            if (db.int("SELECT COUNT(*) FROM user_list_card WHERE card_id = ?", listOf(id)) == 0) {
                db.execute("DELETE FROM card WHERE id = ?", listOf(id))
            }
        }
    }
}
