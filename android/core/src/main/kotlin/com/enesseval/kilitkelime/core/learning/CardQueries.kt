package com.enesseval.kilitkelime.core.learning

import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.query
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.CardState
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.DeckTag
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.WidgetContent
import java.time.LocalDate

/** Narrow queries over cards (port of `CardQueries.swift`). */
object CardQueries {
    /**
     * Cards in any of [decks] with their learning state. Course cards count only once their unit
     * is started. [day] marks learned words due for review; [content] keeps words or phrases.
     */
    fun candidates(decks: List<DeckID>, db: SqlDb, day: LocalDate? = null, content: WidgetContent = WidgetContent.ALL): List<SchedulerCandidate> {
        var filter = sourceFilter(decks, db) ?: return emptyList()
        content.condition?.let { filter = filter + " AND " + it }
        val sql = Sql(
            """SELECT c.id, COALESCE(s.state, 'new') AS state, s.last_shown_at,
                      COALESCE(s.correct_streak, 0) AS streak, s.last_answered_on
               FROM card c LEFT JOIN card_state s ON s.card_id = c.id WHERE """,
        ) + filter
        return db.query(sql) { row ->
            val state = LearningState.fromRaw(row.string("state")) ?: LearningState.NEW
            val last = row.localDate("last_answered_on")
            val due = day != null && state == LearningState.LEARNED && last != null &&
                SpacedReview.isDue(CardState(row.requireString("id"), state, row.int("streak") ?: 0, lastAnsweredOn = last), day)
            SchedulerCandidate(row.requireString("id"), state, row.instant("last_shown_at"), due)
        }
    }

    /**
     * What the lock screen and Quick Review draw from: [decks] (course cards of started units)
     * and the lists that are on. When every deck is off but a list is on, only the lists count.
     */
    fun sourceFilter(decks: List<DeckID>, db: SqlDb): Sql? {
        val prefs = Preferences.load(db)
        val lists = UserLists.hasEnabledLists(db)
        val used = if (prefs.enabledDecks.isEmpty() && lists) emptyList() else decks
        val deckClause = deckFilter(used, Curriculum.startedFilter(db))
        return when {
            deckClause != null && lists -> Sql("(") + deckClause + " OR " + UserLists.enabledListsCondition + ")"
            deckClause != null -> deckClause
            lists -> UserLists.enabledListsCondition
            else -> null
        }
    }

    /** Cards that belong to any of [decks]; null when empty. Exam decks ignore [started]. */
    fun deckFilter(decks: List<DeckID>, started: Sql = Sql("1")): Sql? {
        val levels = decks.mapNotNull { it.level }
        val tags = decks.mapNotNull { it.tag }
        val clauses = mutableListOf<Sql>()
        if (levels.isNotEmpty()) {
            clauses += Sql("(c.level IN ") + Sql.list(levels) +
                Sql(" AND EXISTS (SELECT 1 FROM card_deck d WHERE d.card_id = c.id AND d.deck = ?) AND ", listOf(DeckTag.GENERAL)) +
                started + ")"
        }
        if (tags.isNotEmpty()) {
            clauses += Sql("EXISTS (SELECT 1 FROM card_deck d WHERE d.card_id = c.id AND d.deck IN ") + Sql.list(tags) + ")"
        }
        return if (clauses.isEmpty()) null else Sql("(") + Sql.join(clauses, " OR ") + ")"
    }

    /**
     * Up to [count] distinct English words to use as wrong options for [card]: same level and part
     * of speech first, then same part of speech, then anything. Never a word sharing a meaning.
     */
    fun distractors(card: Card, count: Int, db: SqlDb, rng: RandomSource): List<String> {
        val chosen = mutableListOf<String>()
        val seen = mutableSetOf(card.word)
        val meanings = Card.normalizedMeanings(card.tr)
        val phrase = PartOfSpeech.PHRASE.raw
        val tiers = listOf(
            Sql("level = ? AND pos = ?", listOf(card.level, card.pos)),
            Sql("pos = ?", listOf(card.pos)),
            if (card.isPhrase) Sql("pos = ?", listOf(phrase)) else Sql("pos <> ?", listOf(phrase)),
        )
        for (tier in tiers) {
            if (chosen.size >= count) break
            val cards = db.query(Sql("SELECT * FROM card WHERE ") + tier + Sql(" AND id <> ? ORDER BY id", listOf(card.id)), Card::from)
            for (other in cards.shuffledWith(rng)) {
                if (chosen.size >= count) break
                if (other.word in seen) continue
                if (Card.normalizedMeanings(other.tr).intersect(meanings).isNotEmpty()) continue
                chosen += other.word
                seen += other.word
            }
        }
        return chosen
    }

    /** The answer plus distractors, shuffled. */
    fun quizOptions(card: Card, optionCount: Int, db: SqlDb, rng: RandomSource): List<String> {
        val wrong = distractors(card, optionCount - 1, db, rng)
        return (listOf(card.word) + wrong).shuffledWith(rng)
    }

    fun card(id: String, db: SqlDb): Card? = db.query("SELECT * FROM card WHERE id = ?", listOf(id), Card::from).firstOrNull()

    fun cards(ids: Collection<String>, db: SqlDb): List<Card> =
        ids.chunked(500).flatMap { chunk -> db.query(Sql("SELECT * FROM card WHERE id IN ") + Sql.list(chunk), Card::from) }
}
