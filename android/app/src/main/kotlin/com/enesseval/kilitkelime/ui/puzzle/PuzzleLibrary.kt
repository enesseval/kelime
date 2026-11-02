package com.enesseval.kilitkelime.ui.puzzle

import android.content.Context
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.crossword.CoursePuzzle
import com.enesseval.kilitkelime.core.crossword.Crossword
import com.enesseval.kilitkelime.core.crossword.DailyPuzzle
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.model.CEFRLevel
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap

/**
 * Daily puzzles (port of `PuzzleLibrary`): a level with units makes its puzzle from the started
 * units (`CoursePuzzle`); other levels use the bundled puzzle files when they exist.
 */
object PuzzleLibrary {
    private val cache = ConcurrentHashMap<CEFRLevel, List<Crossword>>()

    fun availableLevels(context: Context): List<CEFRLevel> {
        val files = runCatching { context.assets.list("content/puzzles")?.toList() }.getOrNull().orEmpty()
        return CEFRLevel.entries.filter { "${it.raw}.json" in files }
    }

    private fun puzzles(context: Context, level: CEFRLevel): List<Crossword> = cache.getOrPut(level) {
        runCatching {
            context.assets.open("content/puzzles/${level.raw}.json").bufferedReader().use { DailyPuzzle.decode(it.readText()).puzzles }
        }.getOrDefault(emptyList())
    }

    fun daily(context: Context, preferred: CEFRLevel, day: LocalDate, db: SqlDb): Pair<CEFRLevel, Crossword>? {
        if (preferred in Curriculum.levels(db)) return CoursePuzzle.daily(preferred, day, db)?.let { preferred to it }
        val level = DailyPuzzle.level(preferred, availableLevels(context)) ?: return null
        return DailyPuzzle.pick(puzzles(context, level), day)?.let { level to it }
    }
}
