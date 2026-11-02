package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.db.RawValue

/** A user-facing deck: a level deck (general words of one level) or an exam deck. */
enum class DeckID(override val raw: String) : RawValue {
    A1("A1"), A2("A2"), B1("B1"), B2("B2"), C1("C1"), C2("C2"),
    YDS("YDS"), YOKDIL("YÖKDİL"), IELTS("IELTS");

    /** For level decks, the level they hold. */
    val level: CEFRLevel?
        get() = when (this) {
            A1 -> CEFRLevel.A1
            A2 -> CEFRLevel.A2
            B1 -> CEFRLevel.B1
            B2 -> CEFRLevel.B2
            C1 -> CEFRLevel.C1
            C2 -> CEFRLevel.C2
            else -> null
        }

    /** For exam decks, the tag their cards carry. */
    val tag: DeckTag?
        get() = when (this) {
            YDS -> DeckTag.YDS
            YOKDIL -> DeckTag.YOKDIL
            IELTS -> DeckTag.IELTS
            else -> null
        }

    companion object {
        fun fromRaw(raw: String?): DeckID? = entries.firstOrNull { it.raw == raw }

        /** Default word decks for a learner past the beginner course. */
        val basicDecks: List<DeckID> = listOf(A2, B1)

        /** The decks the widget and reviews draw from; falls back to the basic decks. */
        fun entitled(enabled: List<DeckID>): List<DeckID> = enabled.ifEmpty { basicDecks }

        fun forLevel(level: CEFRLevel): DeckID = entries.first { it.level == level }
    }
}
