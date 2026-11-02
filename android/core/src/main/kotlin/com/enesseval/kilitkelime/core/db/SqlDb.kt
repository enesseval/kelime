package com.enesseval.kilitkelime.core.db

import java.time.Instant
import com.enesseval.kilitkelime.core.dates.LocalDates
import java.time.LocalDate

/**
 * The narrow database interface every query in `:core` runs through.
 *
 * The SQL is the same as the iOS app's (GRDB). On Android it is backed by
 * `android.database.sqlite.SQLiteDatabase`; in tests by SQLite over JDBC.
 *
 * Argument values may be String, Int, Long, Double, Boolean, [LocalDate], [Instant], an enum with a
 * raw value ([RawValue]) or null; [SqlArgs.normalize] turns them into what SQLite stores.
 */
interface SqlDb {
    fun execute(sql: String, args: List<Any?> = emptyList())
    fun <T> query(sql: String, args: List<Any?> = emptyList(), map: (SqlRow) -> T): List<T>
    /** Runs [block] in a transaction; nested calls join the outer transaction. */
    fun <T> transaction(block: () -> T): T
}

/** One result row, read by column name. */
interface SqlRow {
    fun string(column: String): String?
    fun long(column: String): Long?
    fun double(column: String): Double?
    fun has(column: String): Boolean
    /** First-column (index 0) and other positional reads, for single-value queries. */
    fun stringAt(index: Int): String?
    fun longAt(index: Int): Long?

    fun int(column: String): Int? = long(column)?.toInt()
    fun bool(column: String): Boolean = (long(column) ?: 0L) != 0L
    fun instant(column: String): Instant? = long(column)?.let(Instant::ofEpochMilli)
    fun localDate(column: String): LocalDate? = string(column)?.let(LocalDates::parse)
    fun requireString(column: String): String = string(column) ?: error("column $column is null")
}

/** Enums stored by a raw text value ("adj", "A1", "struggling"). */
interface RawValue {
    val raw: String
}

object SqlArgs {
    /** Converts a Kotlin value to String, Long, Double or null for binding. */
    fun normalize(value: Any?): Any? = when (value) {
        null -> null
        is String -> value
        is Boolean -> if (value) 1L else 0L
        is Int -> value.toLong()
        is Long -> value
        is Double -> value
        is Float -> value.toDouble()
        is LocalDate -> value.toString()
        is Instant -> value.toEpochMilli()
        is RawValue -> value.raw
        else -> error("Unsupported SQL argument: ${value::class}")
    }
}

/** A fragment of SQL with its arguments, so conditions can be composed like GRDB's `SQL`. */
class Sql(val text: String, val args: List<Any?> = emptyList()) {
    operator fun plus(other: Sql) = Sql(text + other.text, args + other.args)
    operator fun plus(other: String) = Sql(text + other, args)

    override fun toString() = text

    companion object {
        /** `(?, ?, ?)` for an IN clause. An empty list gives `()`, which SQLite treats as no match. */
        fun list(values: Collection<Any?>): Sql = Sql(values.joinToString(",", "(", ")") { "?" }, values.toList())

        fun join(parts: List<Sql>, separator: String): Sql {
            var result = Sql("")
            parts.forEachIndexed { i, part -> result = if (i == 0) part else result + separator + part }
            return result
        }
    }
}

operator fun String.plus(sql: Sql) = Sql(this + sql.text, sql.args)

fun <T> SqlDb.query(sql: Sql, map: (SqlRow) -> T): List<T> = query(sql.text, sql.args, map)
fun SqlDb.execute(sql: Sql) = execute(sql.text, sql.args)

fun SqlDb.longOrNull(sql: String, args: List<Any?> = emptyList()): Long? =
    query(sql, args) { row -> row.longAt(0) }.firstOrNull()

fun SqlDb.long(sql: String, args: List<Any?> = emptyList()): Long = longOrNull(sql, args) ?: 0L
fun SqlDb.long(sql: Sql): Long = long(sql.text, sql.args)
fun SqlDb.int(sql: String, args: List<Any?> = emptyList()): Int = long(sql, args).toInt()
fun SqlDb.int(sql: Sql): Int = long(sql).toInt()

fun SqlDb.strings(sql: String, args: List<Any?> = emptyList()): List<String> =
    query(sql, args) { it.stringAt(0) }.filterNotNull()

fun SqlDb.stringOrNull(sql: String, args: List<Any?> = emptyList()): String? =
    query(sql, args) { it.stringAt(0) }.firstOrNull()
