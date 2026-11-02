package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.db.RawValue
import com.enesseval.kilitkelime.core.db.SqlRow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import java.util.Locale

@Serializable
enum class PartOfSpeech(override val raw: String) : RawValue {
    @SerialName("adj") ADJECTIVE("adj"),
    @SerialName("n") NOUN("n"),
    @SerialName("v") VERB("v"),
    @SerialName("adv") ADVERB("adv"),
    @SerialName("prep") PREPOSITION("prep"),
    @SerialName("conj") CONJUNCTION("conj"),
    /** A phrase card ("How much is it?"), not a single word. */
    @SerialName("phrase") PHRASE("phrase");

    /** The Turkish name shown on cards and widgets. */
    val label: String
        get() = when (this) {
            ADJECTIVE -> "sıfat"
            NOUN -> "isim"
            VERB -> "fiil"
            ADVERB -> "zarf"
            PREPOSITION -> "edat"
            CONJUNCTION -> "bağlaç"
            PHRASE -> "kalıp"
        }

    companion object {
        fun fromRaw(raw: String?): PartOfSpeech? = entries.firstOrNull { it.raw == raw }
    }
}

@Serializable
enum class CEFRLevel(override val raw: String) : RawValue {
    @SerialName("A1") A1("A1"),
    @SerialName("A2") A2("A2"),
    @SerialName("B1") B1("B1"),
    @SerialName("B2") B2("B2"),
    @SerialName("C1") C1("C1"),
    @SerialName("C2") C2("C2");

    companion object {
        fun fromRaw(raw: String?): CEFRLevel? = entries.firstOrNull { it.raw == raw }
    }
}

/** Tag decks a card can belong to. Level decks come from [Card.level]. */
@Serializable
enum class DeckTag(override val raw: String) : RawValue {
    @SerialName("general") GENERAL("general"),
    @SerialName("yds") YDS("yds"),
    @SerialName("yokdil") YOKDIL("yokdil"),
    @SerialName("ielts") IELTS("ielts");

    companion object {
        fun fromRaw(raw: String?): DeckTag? = entries.firstOrNull { it.raw == raw }
    }
}

/** A further meaning of a card's word, shown on the word detail screen. */
@Serializable
data class CardSense(
    val pos: PartOfSpeech,
    val tr: List<String>,
    @SerialName("example_en") val exampleEN: String,
    @SerialName("example_tr") val exampleTR: String,
) {
    val meaning: String get() = tr.joinToString(", ")
}

/** One vocabulary card. Content from `Content/cards.json`, or a word the learner typed ("user-…"). */
@Serializable
data class Card(
    val id: String,
    val word: String,
    val pos: PartOfSpeech,
    val level: CEFRLevel,
    val tr: List<String>,
    @SerialName("example_en") val exampleEN: String,
    @SerialName("example_tr") val exampleTR: String,
    val note: String? = null,
    val senses: List<CardSense>? = null,
) {
    /** Meanings joined for display: "isteksiz, gönülsüz". */
    val meaning: String get() = tr.joinToString(", ")
    val isPhrase: Boolean get() = pos == PartOfSpeech.PHRASE

    /** One word of plain A–Z letters, so it fits a crossword or letter boxes. */
    val isSingleWord: Boolean
        get() = !isPhrase && word.isNotEmpty() && word.all { it in 'a'..'z' || it in 'A'..'Z' }

    /** First Turkish meaning, for compact places. */
    val primaryMeaning: String get() = tr.firstOrNull() ?: ""

    /** Self-test prompt: the first letter, then one blank per remaining letter ("r________"). */
    val selfTestPattern: Pair<String, String>
        get() {
            val space = word.indexOf(' ')
            if (!isPhrase || space < 0) {
                return word.take(1) to "_".repeat(maxOf(word.length - 1, 0))
            }
            // Phrases keep their first word and their shape: "Make ________ __ _____."
            val rest = word.substring(space).map { if (it.isLetter()) "_" else it.toString() }.joinToString("")
            return word.substring(0, space) to rest
        }

    companion object {
        private val trLocale = Locale.forLanguageTag("tr-TR")

        /** Meanings lowercased with Turkish rules, to spot cards that would share a clue. */
        fun normalizedMeanings(tr: List<String>): Set<String> =
            tr.map { it.trim().lowercase(trLocale) }.toSet()

        /** Reads a card from a row holding the `card` table's columns. */
        fun from(row: SqlRow): Card = Card(
            id = row.requireString("id"),
            word = row.requireString("word"),
            pos = PartOfSpeech.fromRaw(row.string("pos")) ?: PartOfSpeech.NOUN,
            level = CEFRLevel.fromRaw(row.string("level")) ?: CEFRLevel.B1,
            tr = row.string("tr")?.let { Json.decodeFromString(ListSerializer(String.serializer()), it) } ?: emptyList(),
            exampleEN = row.string("example_en") ?: "",
            exampleTR = row.string("example_tr") ?: "",
            note = row.string("note"),
            senses = row.string("senses")?.let { Json.decodeFromString(ListSerializer(CardSense.serializer()), it) },
        )
    }
}
