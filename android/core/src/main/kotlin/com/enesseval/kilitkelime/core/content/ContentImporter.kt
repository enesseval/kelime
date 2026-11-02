package com.enesseval.kilitkelime.core.content

import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardSense
import com.enesseval.kilitkelime.core.model.DeckTag
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer

/** Shape of `Content/cards.json`. */
@Serializable
data class CardsFile(
    val contentVersion: Int,
    val cards: List<ContentCard>,
    val units: List<ContentUnit>? = null,
)

/** A card as written in `cards.json`: the card fields plus its tag decks. */
@Serializable
data class ContentCard(
    val id: String,
    val word: String,
    val pos: PartOfSpeech,
    val level: CEFRLevel,
    val tr: List<String>,
    @SerialName("example_en") val exampleEN: String,
    @SerialName("example_tr") val exampleTR: String,
    val note: String? = null,
    val senses: List<CardSense>? = null,
    val decks: List<DeckTag>,
) {
    val card: Card get() = Card(id, word, pos, level, tr, exampleEN, exampleTR, note, senses)

    companion object {
        fun of(card: Card, decks: List<DeckTag>) = ContentCard(
            card.id, card.word, card.pos, card.level, card.tr, card.exampleEN, card.exampleTR, card.note, card.senses, decks,
        )
    }
}

/** A unit as written in `cards.json`, with its card ids in order. */
@Serializable
data class ContentUnit(
    val id: String,
    val level: CEFRLevel,
    val title: String,
    val goal: String,
    val placement: UnitPlacement,
    val position: Int,
    val stories: List<UnitStory>,
    val cards: List<String>,
)

sealed interface ImportResult {
    data class UpToDate(val version: Int) : ImportResult
    data class Imported(val version: Int, val cardCount: Int) : ImportResult
}

/**
 * Imports cards into the database (port of `ContentImporter.swift`). Runs on first launch and
 * whenever `contentVersion` goes up; one transaction; progress is never touched.
 */
object ContentImporter {
    private val stringList = ListSerializer(String.serializer())
    private val senseList = ListSerializer(CardSense.serializer())

    fun decode(text: String): CardsFile = Json.decodeFromString(CardsFile.serializer(), text)

    fun encode(file: CardsFile): String = Json.encodeToString(CardsFile.serializer(), file)

    fun hasContent(db: SqlDb): Boolean = db.int("SELECT COUNT(*) FROM card") > 0

    fun importIfNeeded(text: String, db: SqlDb, progress: (Double) -> Unit = {}): ImportResult {
        val file = decode(text)
        val current = Settings.int(db, SettingKey.CONTENT_VERSION)
        // Never steps back: older bundled content keeps a newer download.
        if (current != null && current >= file.contentVersion && hasContent(db)) {
            progress(1.0)
            return ImportResult.UpToDate(file.contentVersion)
        }
        db.transaction { apply(file, db, progress) }
        return ImportResult.Imported(file.contentVersion, file.cards.size)
    }

    internal fun apply(file: CardsFile, db: SqlDb, progress: (Double) -> Unit) {
        val incoming = file.cards.map { it.id }.toSet()
        val existing = db.strings("SELECT id FROM card").toSet()
        // Dropped cards leave the rotation; their progress stays. Own words always stay.
        val removed = (existing - incoming).filter { !it.startsWith(UserLists.CUSTOM_PREFIX) }
        for (chunk in removed.chunked(500)) {
            db.execute("DELETE FROM card WHERE id IN (${chunk.joinToString(",") { "?" }})", chunk)
        }
        val total = maxOf(file.cards.size, 1)
        val step = maxOf(total / 50, 1)
        file.cards.forEachIndexed { index, item ->
            upsert(item.card, db)
            db.execute("DELETE FROM card_deck WHERE card_id = ?", listOf(item.id))
            for (deck in item.decks.toSet()) {
                db.execute("INSERT INTO card_deck (card_id, deck) VALUES (?, ?)", listOf(item.id, deck))
            }
            if (index % step == 0) progress(index.toDouble() / total)
        }
        Curriculum.replace(file.units ?: emptyList(), db)
        Settings.setInt(db, SettingKey.CONTENT_VERSION, file.contentVersion)
        progress(1.0)
    }

    /**
     * Inserts or updates a card row without deleting it (so `card_deck` rows survive). Done as
     * INSERT OR IGNORE + UPDATE: `ON CONFLICT DO UPDATE` needs SQLite 3.24, newer than API 26–29.
     */
    fun upsert(card: Card, db: SqlDb) {
        val tr = Json.encodeToString(stringList, card.tr)
        val senses = card.senses?.let { Json.encodeToString(senseList, it) }
        db.execute(
            "INSERT OR IGNORE INTO card (id, word, pos, level, tr, example_en, example_tr, note, senses) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            listOf(card.id, card.word, card.pos, card.level, tr, card.exampleEN, card.exampleTR, card.note, senses),
        )
        db.execute(
            "UPDATE card SET word = ?, pos = ?, level = ?, tr = ?, example_en = ?, example_tr = ?, note = ?, senses = ? WHERE id = ?",
            listOf(card.word, card.pos, card.level, tr, card.exampleEN, card.exampleTR, card.note, senses, card.id),
        )
    }

    /** Inserts a new card; fails if the id exists. */
    fun insert(card: Card, db: SqlDb) {
        db.execute(
            "INSERT INTO card (id, word, pos, level, tr, example_en, example_tr, note, senses) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            listOf(
                card.id, card.word, card.pos, card.level, Json.encodeToString(stringList, card.tr),
                card.exampleEN, card.exampleTR, card.note, card.senses?.let { Json.encodeToString(senseList, it) },
            ),
        )
    }
}
