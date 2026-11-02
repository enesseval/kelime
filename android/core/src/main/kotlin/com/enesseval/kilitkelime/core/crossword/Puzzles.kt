package com.enesseval.kilitkelime.core.crossword

import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.dayIndex
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.PuzzleProgress
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.widgets.WidgetTimelineBuilder
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import kotlin.math.abs

/** Shape of `Content/puzzles/<LEVEL>.json`. */
@Serializable
data class PuzzleFile(val level: String, val puzzles: List<Crossword>)

object DailyPuzzle {
    /** Today's bundled puzzle: `puzzles[dayIndex % count]`. */
    fun pick(puzzles: List<Crossword>, day: LocalDate): Crossword? {
        if (puzzles.isEmpty()) return null
        val n = puzzles.size
        return puzzles[((day.dayIndex % n) + n) % n]
    }

    fun decode(text: String): PuzzleFile = Json.decodeFromString(PuzzleFile.serializer(), text)

    /** The user's level, or the nearest one that has puzzles. */
    fun level(preferred: CEFRLevel, available: List<CEFRLevel>): CEFRLevel? {
        if (available.isEmpty()) return null
        if (preferred in available) return preferred
        return available.minByOrNull { abs(it.ordinal - preferred.ordinal) }
    }

    fun key(level: CEFRLevel, day: LocalDate) = "daily-${level.raw}-$day"

    /** Clue text: meaning plus letter count, e.g. "tereddüt etmek (8)". */
    fun clue(meaning: String, length: Int) = "$meaning ($length)"
}

/**
 * The daily puzzle for a level with units (port of `CoursePuzzle.swift`): made once a day from the
 * current unit, struggling words first, and kept under `<daily key>-grid`.
 */
object CoursePuzzle {
    internal fun gridKey(level: CEFRLevel, day: LocalDate) = DailyPuzzle.key(level, day) + "-grid"

    fun stored(level: CEFRLevel, day: LocalDate, db: SqlDb): Crossword? {
        val row = PuzzleProgress.fetch(db, gridKey(level, day)) ?: return null
        return runCatching { Json.decodeFromString(Crossword.serializer(), row.cells) }.getOrNull()
    }

    fun daily(level: CEFRLevel, day: LocalDate, db: SqlDb): Crossword? = stored(level, day, db) ?: make(level, day, db)

    /** Makes today's grid and keeps it, if the level has units. */
    fun keepToday(clock: AppClock, db: SqlDb) {
        val level = Preferences.load(db).level
        val day = clock.today
        if (db.int("SELECT COUNT(*) FROM unit WHERE level = ?", listOf(level)) == 0) return
        if (stored(level, day, db) != null) return
        val puzzle = make(level, day, db) ?: return
        PuzzleProgress(gridKey(level, day), Json.encodeToString(Crossword.serializer(), puzzle)).save(db)
    }

    internal fun make(level: CEFRLevel, day: LocalDate, db: SqlDb): Crossword? {
        val started = Curriculum.started(db)
        val units = Curriculum.units(level, db)
        val current = Curriculum.state(db)?.currentID
        if (current != null) make(level, day, listOf(current), db)?.let { return it }
        return make(level, day, units.map { it.id }.filter { it in started || it == current }, db)
    }

    internal fun make(level: CEFRLevel, day: LocalDate, units: List<String>, db: SqlDb): Crossword? {
        val pool = mutableListOf<Card>()
        val seen = mutableSetOf<String>()
        for (unit in units) for (card in Curriculum.cards(unit, db)) {
            if (seen.add(card.id) && card.isSingleWord && card.word.length in 3..CrosswordGenerator.MAX_SIZE) pool += card
        }
        val ids = pool.map { it.id }.toSet()
        val seeds = WidgetTimelineBuilder.strugglingCards(db, 200).filter { it.id in ids }.take(4)
        val seedIDs = seeds.map { it.id }.toSet()
        val seed = day.dayIndex.toLong().toULong() * 2654435761uL + 7uL
        return CrosswordGenerator.generate(
            "course-${level.raw}-$day",
            seeds.map(CrosswordGenerator::Word),
            pool.filter { it.id !in seedIDs }.map(CrosswordGenerator::Word),
            seed,
        )
    }
}

/** The Pro personal puzzle: struggling words as seeds, learned words (or the sources) as fillers. */
object PersonalPuzzle {
    fun make(db: SqlDb, clock: AppClock, seed: ULong): Crossword? {
        val prefs = Preferences.load(db)
        val usableLength = 3..CrosswordGenerator.MAX_SIZE
        val struggling = WidgetTimelineBuilder.strugglingCards(db, 12).filter { it.isSingleWord && it.word.length in usableLength }
        val seeds = struggling.take(4).map(CrosswordGenerator::Word)
        val decks = prefs.entitledDecks + DeckID.forLevel(prefs.level)
        val ids = CardQueries.candidates(decks, db).map { it.cardID }
        val usable = CardQueries.cards(ids, db).filter { it.isSingleWord && it.word.length in usableLength }
        val learnedIDs = db.strings("SELECT card_id FROM card_state WHERE state = 'learned'").toSet()
        val learned = usable.filter { it.id in learnedIDs }
        val fillers = (if (learned.size >= 12) learned else usable).map(CrosswordGenerator::Word)
        return CrosswordGenerator.generate("personal-${clock.today}-$seed", seeds, fillers, seed)
    }
}

/** Saves and restores crossword progress; hints and solved words become learning events. */
object PuzzleStore {
    data class Saved(val game: CrosswordGame, val seconds: Int, val completedAt: Instant?)

    fun load(key: String, puzzle: Crossword, db: SqlDb): Saved {
        val row = PuzzleProgress.fetch(db, key)
        val snapshot = row?.let { runCatching { CrosswordGame.decodeSnapshot(it.cells) }.getOrNull() }
        if (row == null || snapshot == null || snapshot.grid != puzzle.fingerprint) return Saved(CrosswordGame(puzzle), 0, null)
        return Saved(CrosswordGame.restore(puzzle, snapshot), row.seconds, row.completedAt)
    }

    fun reset(key: String, db: SqlDb) {
        db.execute("DELETE FROM puzzle_progress WHERE puzzle_key IN (?, ?)", listOf(key, "$key-grid"))
    }

    fun save(key: String, game: CrosswordGame, seconds: Int, completedAt: Instant?, db: SqlDb) {
        PuzzleProgress(key, game.encodedSnapshot(), game.hintsUsed, completedAt, seconds).save(db)
    }

    /** A solved word in today's daily puzzle counts the day for the streak. Returns true when newly counted. */
    fun markStudiedIfSolved(game: CrosswordGame, daily: Boolean, day: LocalDate, clock: AppClock, db: SqlDb): Boolean =
        daily && day == clock.today && game.solvedCount > 0 &&
            LearningStore.markStudied(day, com.enesseval.kilitkelime.core.games.StreakSource.PUZZLE, db)

    fun recordHint(entry: CrosswordEntry, clock: AppClock, db: SqlDb) {
        LearningStore.record(LearningEvent.HintUsed, entry.cardID, ReviewSource.PUZZLE, clock, db)
    }

    /** Words solved without help count as correct answers. */
    fun recordCompletion(game: CrosswordGame, clock: AppClock, db: SqlDb) {
        for (entry in game.unaidedEntries) {
            LearningStore.record(LearningEvent.Answered(true), entry.cardID, ReviewSource.PUZZLE, clock, db)
        }
    }

    /** Completed daily puzzles, newest first (the archive). */
    fun completedDays(level: CEFRLevel, db: SqlDb): List<LocalDate> =
        db.strings(
            "SELECT puzzle_key FROM puzzle_progress WHERE puzzle_key LIKE ? AND puzzle_key NOT LIKE '%-grid' AND completed_at IS NOT NULL",
            listOf("daily-${level.raw}-%"),
        ).mapNotNull { LocalDates.parse(it.removePrefix("daily-${level.raw}-")) }.sortedDescending()
}

/** Today's puzzle progress, readable by widgets without the grid. */
data class DailyPuzzleSummary(val day: LocalDate, val solved: Int, val total: Int, val cells: Map<Int, Boolean> = emptyMap()) {
    fun save(db: SqlDb) {
        val grid = cells.keys.sorted().joinToString(",") { "$it:${if (cells[it] == true) 1 else 0}" }
        Settings.set(db, SettingKey.DAILY_PUZZLE_SUMMARY, "$day|$solved|$total|$grid")
    }

    companion object {
        fun of(day: LocalDate, game: CrosswordGame) = DailyPuzzleSummary(day, game.solvedCount, game.puzzle.entries.size, thumbnail(game))

        /** The top-left 8 × 10 of the grid: letter cells, true once their word is solved. */
        fun thumbnail(game: CrosswordGame): Map<Int, Boolean> {
            val cells = HashMap<Int, Boolean>()
            for (entry in game.puzzle.entries) {
                val solved = game.isSolved(entry)
                for (cell in entry.cells) if (cell.col < 8 && cell.row < 10) {
                    val index = cell.row * 8 + cell.col
                    cells[index] = (cells[index] ?: false) || solved
                }
            }
            return cells
        }

        fun load(db: SqlDb): DailyPuzzleSummary? {
            val raw = Settings.string(db, SettingKey.DAILY_PUZZLE_SUMMARY) ?: return null
            val parts = raw.split("|")
            if (parts.size < 3) return null
            val day = LocalDates.parse(parts[0]) ?: return null
            val solved = parts[1].toIntOrNull() ?: return null
            val total = parts[2].toIntOrNull() ?: return null
            val cells = HashMap<Int, Boolean>()
            if (parts.size > 3) for (item in parts[3].split(",")) {
                val pair = item.split(":")
                val index = pair.getOrNull(0)?.toIntOrNull()
                if (pair.size == 2 && index != null) cells[index] = pair[1] == "1"
            }
            return DailyPuzzleSummary(day, solved, total, cells)
        }
    }
}
