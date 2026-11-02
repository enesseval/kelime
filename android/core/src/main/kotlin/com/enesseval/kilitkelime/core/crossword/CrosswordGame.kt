package com.enesseval.kilitkelime.core.crossword

import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.review.ReviewQuestion
import kotlinx.serialization.Serializable

/**
 * The playable state of a crossword (port of `CrosswordGame.swift`). Immutable-style: every
 * action returns nothing and mutates this instance; call [copy] to keep a snapshot for Compose.
 */
class CrosswordGame(val puzzle: Crossword) {
    private val solution: Map<GridPoint, Char> = puzzle.solution

    var typed: Map<GridPoint, Char> = emptyMap(); private set
    /** Cells filled by "Harf aç" or "Kelimeyi göster". */
    var revealed: Set<GridPoint> = emptySet(); private set
    /** Cells marked wrong by "Kelimeyi kontrol et", until retyped. */
    var wrong: Set<GridPoint> = emptySet(); private set
    /** Entries the user needed help with; they become struggling. */
    var helped: Set<String> = emptySet(); private set
    var hintsUsed: Int = 0; private set
    var activeEntryID: String = puzzle.playOrder.first().id; private set
    var cursor: GridPoint = puzzle.playOrder.first().cells[0]; private set

    fun copy(): CrosswordGame = CrosswordGame(puzzle).also {
        it.typed = typed; it.revealed = revealed; it.wrong = wrong; it.helped = helped
        it.hintsUsed = hintsUsed; it.activeEntryID = activeEntryID; it.cursor = cursor
    }

    val activeEntry: CrosswordEntry get() = puzzle.entries.first { it.id == activeEntryID }

    fun isSolved(entry: CrosswordEntry): Boolean = entry.cells.all { typed[it] == solution[it] }
    val isComplete: Boolean get() = puzzle.entries.all(::isSolved)
    val solvedCount: Int get() = puzzle.entries.count(::isSolved)

    /** Entries solved without any help, in clue order. */
    val unaidedEntries: List<CrosswordEntry> get() = puzzle.orderedEntries.filter { isSolved(it) && it.id !in helped }

    /** Types a letter at the cursor (ASCII-uppercased) and moves on. */
    fun type(letter: Char) {
        val upper = ReviewQuestion.asciiUpper(letter.toString()).firstOrNull() ?: return
        if (upper !in 'A'..'Z') return
        if (!isLocked(cursor)) {
            typed = typed + (cursor to upper)
            wrong = wrong - cursor
        }
        moveCursor(1)
    }

    /** Clears the cursor cell, or steps back and clears the previous one when it is empty. */
    fun deleteBackward() {
        if (typed[cursor] != null && !isLocked(cursor)) {
            typed = typed - cursor
            wrong = wrong - cursor
            return
        }
        moveCursor(-1)
        if (!isLocked(cursor)) {
            typed = typed - cursor
            wrong = wrong - cursor
        }
    }

    /**
     * Tapping a cell selects it; tapping the cursor again switches direction at a crossing. At a
     * crossing with a solved word, the unsolved one is chosen.
     */
    fun select(point: GridPoint) {
        val options = puzzle.entriesAt(point)
        if (options.isEmpty()) return
        val unsolved = options.filter { !isSolved(it) }
        val activeHere = options.any { it.id == activeEntryID }
        val other = options.firstOrNull { it.id != activeEntryID }
        if (point == cursor && options.size > 1 && other != null && unsolved.size != 1) {
            activeEntryID = other.id
        } else if (!activeHere || (isSolved(activeEntry) && unsolved.isNotEmpty())) {
            val pick = unsolved.firstOrNull { it.direction == CrosswordDirection.ACROSS } ?: unsolved.firstOrNull()
                ?: options.firstOrNull { it.direction == CrosswordDirection.ACROSS } ?: options[0]
            activeEntryID = pick.id
        }
        cursor = point
        if (isLocked(point) && !isSolved(activeEntry)) {
            val open = activeEntry.cells.firstOrNull { !isLocked(it) && typed[it] == null }
                ?: activeEntry.cells.firstOrNull { !isLocked(it) }
            if (open != null) cursor = open
        }
    }

    /** Next (or previous) unsolved word by number. */
    fun step(delta: Int) {
        val ordered = puzzle.playOrder
        var index = ordered.indexOfFirst { it.id == activeEntryID }
        if (index < 0) return
        for (k in ordered.indices) {
            index = (index + delta + ordered.size) % ordered.size
            if (!isSolved(ordered[index])) break
        }
        focus(ordered[index])
    }

    fun focus(entry: CrosswordEntry) {
        activeEntryID = entry.id
        cursor = entry.cells.firstOrNull { typed[it] == null } ?: entry.cells[0]
    }

    /** "Harf aç": reveals the cursor cell, or the first wrong cell of the word. */
    fun revealLetter(): CrosswordEntry {
        val entry = activeEntry
        val target = if (typed[cursor] == solution[cursor] && cursor in entry.cells) {
            entry.cells.firstOrNull { typed[it] != solution[it] }
        } else cursor
        if (target != null) {
            val letter = solution[target]
            if (letter != null) {
                typed = typed + (target to letter)
                revealed = revealed + target
                wrong = wrong - target
                if (target == cursor) moveCursor(1)
            }
        }
        markHelped(entry)
        return entry
    }

    /** "Kelimeyi kontrol et": marks wrong letters; true when an error showed (counts as help). */
    fun checkWord(): Boolean {
        val entry = activeEntry
        val errors = entry.cells.filter { typed[it] != null && typed[it] != solution[it] }
        wrong = wrong + errors
        if (errors.isNotEmpty()) markHelped(entry)
        return errors.isNotEmpty()
    }

    /** "Kelimeyi göster": fills the word and moves to the next unsolved one. */
    fun revealWord(): CrosswordEntry {
        val entry = activeEntry
        for (cell in entry.cells) {
            if (typed[cell] != solution[cell]) {
                typed = typed + (cell to solution.getValue(cell))
                revealed = revealed + cell
                wrong = wrong - cell
            }
        }
        markHelped(entry)
        if (!isComplete) step(1)
        return entry
    }

    private fun markHelped(entry: CrosswordEntry) {
        hintsUsed += 1
        helped = helped + entry.id
    }

    /** Revealed cells and cells of solved words can't be edited. */
    fun isLocked(point: GridPoint): Boolean = point in revealed || puzzle.entriesAt(point).any(::isSolved)

    private fun moveCursor(delta: Int) {
        val cells = activeEntry.cells
        val index = cells.indexOf(cursor)
        if (index < 0) return
        var i = index + delta
        while (i in cells.indices) {
            if (delta < 0 || !isLocked(cells[i])) {
                cursor = cells[i]; return
            }
            i += delta
        }
        if (delta > 0 && isSolved(activeEntry) && !isComplete) step(1)
    }

    @Serializable
    data class Snapshot(
        val typed: Map<String, String>,
        val revealed: List<String>,
        val wrong: List<String>,
        val helped: List<String>,
        val hintsUsed: Int,
        val grid: String? = null,
    )

    val snapshot: Snapshot
        get() = Snapshot(
            typed = typed.entries.associate { key(it.key) to it.value.toString() },
            revealed = revealed.map(::key).sorted(),
            wrong = wrong.map(::key).sorted(),
            helped = helped.sorted(),
            hintsUsed = hintsUsed,
            grid = puzzle.fingerprint,
        )

    fun encodedSnapshot(): String = Json.encodeToString(Snapshot.serializer(), snapshot)

    companion object {
        private fun key(p: GridPoint) = "${p.row},${p.col}"
        private fun point(key: String): GridPoint? {
            val parts = key.split(",").mapNotNull { it.toIntOrNull() }
            return if (parts.size == 2) GridPoint(parts[0], parts[1]) else null
        }

        fun decodeSnapshot(text: String): Snapshot = Json.decodeFromString(Snapshot.serializer(), text)

        fun restore(puzzle: Crossword, snapshot: Snapshot): CrosswordGame {
            val game = CrosswordGame(puzzle)
            val solution = game.solution
            game.typed = snapshot.typed.mapNotNull { (k, v) ->
                val p = point(k); val ch = v.firstOrNull()
                if (p != null && ch != null && solution[p] != null) p to ch else null
            }.toMap()
            game.revealed = snapshot.revealed.mapNotNull(::point).filter { solution[it] != null }.toSet()
            game.wrong = snapshot.wrong.mapNotNull(::point).filter { solution[it] != null }.toSet()
            game.helped = snapshot.helped.toSet()
            game.hintsUsed = snapshot.hintsUsed
            puzzle.playOrder.firstOrNull { !game.isSolved(it) }?.let(game::focus)
            return game
        }
    }
}
