package com.enesseval.kilitkelime.core.crossword

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** A grid position (row, column), zero-based from the top-left. */
data class GridPoint(val row: Int, val col: Int) : Comparable<GridPoint> {
    override fun compareTo(other: GridPoint): Int = compareValuesBy(this, other, { it.row }, { it.col })
}

@Serializable
enum class CrosswordDirection(val raw: String) {
    @SerialName("a") ACROSS("a"),
    @SerialName("d") DOWN("d");

    val label: String get() = if (this == ACROSS) "Yatay" else "Dikey"
}

/** One answer in a crossword. */
@Serializable
data class CrosswordEntry(
    @SerialName("n") val number: Int,
    @SerialName("dir") val direction: CrosswordDirection,
    @SerialName("r") val row: Int,
    @SerialName("c") val col: Int,
    /** ASCII uppercase answer, e.g. "HESITATE". */
    val answer: String,
    @SerialName("card_id") val cardID: String,
) {
    val id: String get() = "$number${direction.raw}"
    val length: Int get() = answer.length

    val cells: List<GridPoint>
        get() = (answer.indices).map { i -> if (direction == CrosswordDirection.ACROSS) GridPoint(row, col + i) else GridPoint(row + i, col) }

    val letters: List<Char> get() = answer.toList()
}

private val acrossFirst = compareBy<CrosswordEntry>({ if (it.direction == CrosswordDirection.ACROSS) 0 else 1 }, { it.number })
private val byNumber = compareBy<CrosswordEntry>({ it.number }, { if (it.direction == CrosswordDirection.ACROSS) 0 else 1 })

/** A free-form crossword: entries on a width × height grid; every other cell is a block. */
@Serializable
data class Crossword(
    val id: String,
    val width: Int,
    val height: Int,
    val entries: List<CrosswordEntry>,
) {
    /** Identifies the grid layout, so saved progress never applies to a different grid. */
    val fingerprint: String
        get() = entries.map { "${it.row},${it.col}${it.direction.raw}${it.answer}" }.sorted().joinToString(";")

    /** Solution letter for every open cell. */
    val solution: Map<GridPoint, Char>
        get() {
            val grid = HashMap<GridPoint, Char>()
            for (entry in entries) entry.cells.zip(entry.letters).forEach { (p, l) -> grid[p] = l }
            return grid
        }

    /** Clue numbers by starting cell. */
    val numbers: Map<GridPoint, Int>
        get() {
            val map = LinkedHashMap<GridPoint, Int>()
            for (e in entries) map.putIfAbsent(GridPoint(e.row, e.col), e.number)
            return map
        }

    /** Clue order: across first, then down, each by number. */
    val orderedEntries: List<CrosswordEntry> get() = entries.sortedWith(acrossFirst)

    /** Play order: by number, across before down at the same number. */
    val playOrder: List<CrosswordEntry> get() = entries.sortedWith(byNumber)

    fun entriesAt(point: GridPoint): List<CrosswordEntry> = entries.filter { point in it.cells }
}

/** Structural checks shared by bundled puzzles and the generator. */
object CrosswordValidator {
    sealed interface Problem {
        data class OutOfBounds(val id: String) : Problem
        data class Conflict(val point: GridPoint) : Problem
        data class Touching(val point: GridPoint) : Problem
        data class BlockedEnds(val id: String) : Problem
        data class ParallelOverlap(val point: GridPoint) : Problem
        data object Disconnected : Problem
        data class BadNumbering(val id: String) : Problem
        data class NotLetters(val id: String) : Problem
    }

    fun problems(puzzle: Crossword): List<Problem> {
        val problems = mutableListOf<Problem>()
        val owners = HashMap<GridPoint, MutableList<CrosswordEntry>>()
        val letters = HashMap<GridPoint, Char>()
        for (entry in puzzle.entries) {
            if (!entry.answer.all { it in 'A'..'Z' } || entry.answer.length < 2) problems += Problem.NotLetters(entry.id)
            for ((point, letter) in entry.cells.zip(entry.letters)) {
                if (point.row !in 0 until puzzle.height || point.col !in 0 until puzzle.width) {
                    problems += Problem.OutOfBounds(entry.id); break
                }
                val existing = letters[point]
                if (existing != null && existing != letter) problems += Problem.Conflict(point)
                letters[point] = letter
                owners.getOrPut(point) { mutableListOf() }.add(entry)
            }
        }
        for ((point, list) in owners) {
            if (list.map { it.direction }.toSet().size < list.size) problems += Problem.ParallelOverlap(point)
        }
        for (entry in puzzle.entries) {
            val (dr, dc) = if (entry.direction == CrosswordDirection.ACROSS) 0 to 1 else 1 to 0
            val before = GridPoint(entry.row - dr, entry.col - dc)
            val last = entry.cells.last()
            val after = GridPoint(last.row + dr, last.col + dc)
            if (letters[before] != null || letters[after] != null) problems += Problem.BlockedEnds(entry.id)
            for (point in entry.cells) {
                if (owners[point]?.size != 1) continue
                val sides = if (entry.direction == CrosswordDirection.ACROSS) {
                    listOf(GridPoint(point.row - 1, point.col), GridPoint(point.row + 1, point.col))
                } else {
                    listOf(GridPoint(point.row, point.col - 1), GridPoint(point.row, point.col + 1))
                }
                for (side in sides) if (letters[side] != null) problems += Problem.Touching(point)
            }
        }
        if (!isConnected(puzzle)) problems += Problem.Disconnected
        val starts = puzzle.entries.map { GridPoint(it.row, it.col) }.toSet().sorted()
        val expected = starts.withIndex().associate { (i, p) -> p to i + 1 }
        for (entry in puzzle.entries) {
            if (expected[GridPoint(entry.row, entry.col)] != entry.number) problems += Problem.BadNumbering(entry.id)
        }
        return problems
    }

    fun isValid(puzzle: Crossword) = problems(puzzle).isEmpty()

    internal fun isConnected(puzzle: Crossword): Boolean {
        val first = puzzle.entries.firstOrNull() ?: return true
        val seen = mutableSetOf(first.id)
        val queue = ArrayDeque(listOf(first))
        while (queue.isNotEmpty()) {
            val entry = queue.removeLast()
            val cells = entry.cells.toSet()
            for (other in puzzle.entries) {
                if (other.id !in seen && other.cells.any { it in cells }) {
                    seen += other.id
                    queue.addLast(other)
                }
            }
        }
        return seen.size == puzzle.entries.size
    }
}
