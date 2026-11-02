package com.enesseval.kilitkelime.core.queries

import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.content.UnitPlacement
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.query
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.SpacedReview
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.DeckTag
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import java.text.Normalizer
import java.time.LocalDate
import java.util.Locale

/** A card with the user's progress, for lists and the word detail screen. */
data class WordItem(
    val card: Card,
    val state: LearningState,
    val favorite: Boolean,
    val tags: List<DeckTag>,
    val nextReview: LocalDate? = null,
) {
    val id: String get() = card.id

    val deckLabel: String
        get() = when {
            card.id.startsWith(UserLists.CUSTOM_PREFIX) -> "Kendi kelimen"
            DeckTag.YDS in tags -> DeckID.YDS.raw
            DeckTag.YOKDIL in tags -> DeckID.YOKDIL.raw
            DeckTag.IELTS in tags -> DeckID.IELTS.raw
            else -> "Genel"
        }
}

enum class WordSegment(val label: String, val emptyText: String) {
    STRUGGLING("Zorlanılan", "Zorlandığın kelime yok. Bir Hızlı Tekrar ile başla."),
    LEARNED("Öğrenildi", "Henüz öğrendiğin kelime yok. Bir Hızlı Tekrar ile başla."),
    FAVORITES("Favoriler", "Favori kelimen yok. Kelime detayında yıldıza dokun."),
    ALL("Tümü", "Aramana ya da filtrelerine uyan kelime yok."),
}

enum class WordSort(val label: String, internal val orderBy: String) {
    ALPHABETICAL("A–Z", "c.word COLLATE NOCASE"),
    REVERSE_ALPHABETICAL("Z–A", "c.word COLLATE NOCASE DESC"),
    LEVEL("Seviye", "c.level, c.word COLLATE NOCASE"),
    RECENTLY_STUDIED("Son çalışılan", "last_studied IS NULL, last_studied DESC, c.word COLLATE NOCASE"),
    MOST_MISSED("En çok yanlış", "missed DESC, c.word COLLATE NOCASE"),
}

enum class WordKind(val label: String, val partsOfSpeech: List<PartOfSpeech>) {
    NOUN("İsim", listOf(PartOfSpeech.NOUN)),
    VERB("Fiil", listOf(PartOfSpeech.VERB)),
    ADJECTIVE("Sıfat", listOf(PartOfSpeech.ADJECTIVE)),
    ADVERB("Zarf", listOf(PartOfSpeech.ADVERB)),
    PHRASE("Kalıp", listOf(PartOfSpeech.PHRASE)),
    OTHER("Diğer", listOf(PartOfSpeech.PREPOSITION, PartOfSpeech.CONJUNCTION)),
}

data class WordFilter(
    val levels: Set<CEFRLevel> = emptySet(),
    val states: Set<LearningState> = emptySet(),
    val kinds: Set<WordKind> = emptySet(),
) {
    val isEmpty: Boolean get() = levels.isEmpty() && states.isEmpty() && kinds.isEmpty()
    val count: Int get() = levels.size + states.size + kinds.size
}

object WordQueries {
    private val trLocale = Locale.forLanguageTag("tr-TR")
    private val marks = Regex("\\p{Mn}+")

    fun item(id: String, db: SqlDb): WordItem? {
        val card = CardQueries.card(id, db) ?: return null
        val state = CardState.fetch(db, id)
        val tags = db.strings("SELECT deck FROM card_deck WHERE card_id = ? ORDER BY deck", listOf(id)).mapNotNull(DeckTag::fromRaw)
        return WordItem(card, state?.state ?: LearningState.NEW, state?.favorite ?: false, tags, state?.let(SpacedReview::dueDate))
    }

    /** Words for a Kelimelerim segment, filtered by [search] (Turkish-aware, diacritic-insensitive). */
    fun list(
        segment: WordSegment,
        db: SqlDb,
        search: String = "",
        filter: WordFilter = WordFilter(),
        sort: WordSort = WordSort.ALPHABETICAL,
    ): List<WordItem> {
        val conditions = mutableListOf<Sql>()
        when (segment) {
            WordSegment.STRUGGLING -> conditions += Sql("s.state = 'struggling'")
            WordSegment.LEARNED -> conditions += Sql("s.state = 'learned'")
            WordSegment.FAVORITES -> conditions += Sql("s.favorite = 1")
            WordSegment.ALL -> {
                val level = Preferences.load(db).level
                val saved = (Settings.string(db, SettingKey.UNITS_STARTED) ?: "").split(",").filter { it.isNotEmpty() }
                val units = saved + db.strings("SELECT id FROM unit WHERE placement = ? AND level = ?", listOf(UnitPlacement.FIRST, level))
                val unitList = if (units.isEmpty()) Sql("(NULL)") else Sql.list(units)
                conditions += Sql("(EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id AND uc.unit_id IN ") + unitList +
                    ") OR EXISTS (SELECT 1 FROM user_list_card ulc WHERE ulc.card_id = c.id)" +
                    " OR s.state IN ('struggling', 'learned') OR s.favorite = 1)"
            }
        }
        if (filter.levels.isNotEmpty()) conditions += Sql("c.level IN ") + Sql.list(filter.levels.sorted().map { it.raw })
        if (filter.states.isNotEmpty()) conditions += Sql("COALESCE(s.state, 'new') IN ") + Sql.list(filter.states.map { it.raw }.sorted())
        if (filter.kinds.isNotEmpty()) conditions += Sql("c.pos IN ") + Sql.list(filter.kinds.flatMap { k -> k.partsOfSpeech.map { it.raw } }.sorted())
        var sql = Sql(
            """SELECT c.*, COALESCE(s.state, 'new') AS user_state, COALESCE(s.favorite, 0) AS user_favorite,
                 (SELECT MAX(r.answered_at) FROM review_log r WHERE r.card_id = c.id) AS last_studied,
                 (SELECT COUNT(*) FROM review_log r WHERE r.card_id = c.id AND r.correct = 0) AS missed
               FROM card c LEFT JOIN card_state s ON s.card_id = c.id """,
        )
        if (conditions.isNotEmpty()) sql = sql + "WHERE " + Sql.join(conditions, " AND ")
        sql = sql + " ORDER BY " + sort.orderBy
        val needle = normalize(search)
        return db.query(sql) { row ->
            WordItem(Card.from(row), LearningState.fromRaw(row.string("user_state")) ?: LearningState.NEW, row.bool("user_favorite"), emptyList())
        }.filter { item ->
            needle.isEmpty() || normalize(item.card.word).contains(needle) || normalize(item.card.meaning).contains(needle)
        }
    }

    /** Lowercases with Turkish rules and strips diacritics: "IŞIK", "ışık" and "isik" match. */
    fun normalize(text: String): String {
        val lower = text.trim().lowercase(trLocale)
        return marks.replace(Normalizer.normalize(lower, Normalizer.Form.NFD), "").replace("ı", "i")
    }
}

/** Progress of one deck. */
data class DeckProgress(val deck: DeckID, val total: Int, val learned: Int, val enabled: Boolean) {
    val fraction: Double get() = if (total == 0) 0.0 else learned.toDouble() / total
    val isFinished: Boolean get() = total > 0 && learned == total
}

object DeckQueries {
    fun progress(db: SqlDb): List<DeckProgress> {
        val prefs = Preferences.load(db)
        return DeckID.entries.map { deck ->
            val filter = CardQueries.deckFilter(listOf(deck)) ?: return@map DeckProgress(deck, 0, 0, false)
            db.query(
                Sql(
                    """SELECT COUNT(*) AS total, SUM(CASE WHEN s.state = 'learned' THEN 1 ELSE 0 END) AS learned
                       FROM card c LEFT JOIN card_state s ON s.card_id = c.id WHERE """,
                ) + filter,
            ) { DeckProgress(deck, it.int("total") ?: 0, it.int("learned") ?: 0, deck in prefs.enabledDecks) }.first()
        }
    }

    fun courseEnabled(db: SqlDb): Boolean = Preferences.load(db).enabledDecks.any { it.level != null }

    /** Turns the whole course on or off for the lock screen and Quick Review. */
    fun setCourse(enabled: Boolean, db: SqlDb) {
        val prefs = Preferences.load(db)
        val decks = prefs.enabledDecks.filter { it.level == null }.toMutableList()
        if (enabled) {
            val levels = Curriculum.levels(db).filter { it <= prefs.level }
            val course = DeckID.entries.filter { d -> d.level?.let { it in levels } ?: false }
            decks += course.ifEmpty { listOf(DeckID.forLevel(prefs.level)) }
        }
        prefs.copy(enabledDecks = decks).save(db)
    }

    fun setEnabled(enabled: Boolean, deck: DeckID, db: SqlDb) {
        val prefs = Preferences.load(db)
        val decks = if (enabled) {
            if (deck in prefs.enabledDecks) prefs.enabledDecks else prefs.enabledDecks + deck
        } else {
            prefs.enabledDecks - deck
        }
        prefs.copy(enabledDecks = decks).save(db)
    }
}
