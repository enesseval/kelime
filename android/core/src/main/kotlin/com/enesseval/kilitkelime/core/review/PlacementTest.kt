package com.enesseval.kilitkelime.core.review

import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.learning.RandomSource
import com.enesseval.kilitkelime.core.learning.shuffledWith
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card

/** One placement question: an English word with four Turkish meanings. */
data class PlacementQuestion(val card: Card, val options: List<String>) {
    val id: String get() = card.id
    val answer: String get() = card.meaning
}

/**
 * The optional placement test: two words per level from A1 up; stops after two levels in a row
 * that are not known; the result is the highest known level (port of `PlacementTest.swift`).
 */
object PlacementTest {
    const val PER_LEVEL = 2

    fun questions(db: SqlDb, rng: RandomSource): Map<CEFRLevel, List<PlacementQuestion>> {
        val result = LinkedHashMap<CEFRLevel, List<PlacementQuestion>>()
        for (level in CEFRLevel.entries) {
            val cards = db.query(
                """SELECT c.* FROM card c WHERE c.level = ? AND c.pos <> 'phrase'
                   AND EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id) ORDER BY c.id""",
                listOf(level), Card::from,
            ).filter { it.isSingleWord }
            if (cards.size < PER_LEVEL + 3) continue
            val picked = cards.shuffledWith(rng).take(PER_LEVEL)
            result[level] = picked.map { card ->
                val wrong = cards.filter { it.id != card.id && it.meaning != card.meaning }.shuffledWith(rng).take(3).map { it.meaning }
                PlacementQuestion(card, (listOf(card.meaning) + wrong).shuffledWith(rng))
            }
        }
        return result
    }

    fun nextLevel(scores: List<Pair<CEFRLevel, Int>>, available: List<CEFRLevel>): CEFRLevel? {
        val misses = scores.takeLast(2).count { it.second < PER_LEVEL }
        if (scores.size >= 2 && misses == 2) return null
        val asked = scores.map { it.first }.toSet()
        return available.sorted().firstOrNull { it !in asked }
    }

    fun result(scores: List<Pair<CEFRLevel, Int>>, available: List<CEFRLevel>): CEFRLevel {
        val known = scores.filter { it.second >= PER_LEVEL }.maxOfOrNull { it.first } ?: CEFRLevel.A1
        return available.filter { it <= known }.maxOrNull() ?: available.minOrNull() ?: CEFRLevel.A1
    }
}
