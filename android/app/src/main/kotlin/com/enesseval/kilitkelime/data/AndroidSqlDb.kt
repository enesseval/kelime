package com.enesseval.kilitkelime.data

import android.database.Cursor
import android.database.sqlite.SQLiteCursor
import android.database.sqlite.SQLiteDatabase
import com.enesseval.kilitkelime.core.db.Migrations
import com.enesseval.kilitkelime.core.db.SqlArgs
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.SqlRow
import java.io.File

/**
 * [SqlDb] over the platform SQLite. Arguments are bound with their types (rawQuery would bind
 * everything as text), so `LIMIT ?` and integer comparisons behave as in the JVM tests.
 */
class AndroidSqlDb(private val db: SQLiteDatabase) : SqlDb {

    override fun execute(sql: String, args: List<Any?>) {
        if (args.isEmpty()) db.execSQL(sql) else db.execSQL(sql, args.map(SqlArgs::normalize).toTypedArray())
    }

    override fun <T> query(sql: String, args: List<Any?>, map: (SqlRow) -> T): List<T> {
        val values = args.map(SqlArgs::normalize)
        val factory = SQLiteDatabase.CursorFactory { _, driver, editTable, query ->
            values.forEachIndexed { i, v ->
                when (v) {
                    null -> query.bindNull(i + 1)
                    is Long -> query.bindLong(i + 1, v)
                    is Double -> query.bindDouble(i + 1, v)
                    is String -> query.bindString(i + 1, v)
                    else -> query.bindString(i + 1, v.toString())
                }
            }
            SQLiteCursor(driver, editTable, query)
        }
        db.rawQueryWithFactory(factory, sql, null, null).use { cursor ->
            val row = CursorRow(cursor)
            val out = ArrayList<T>(cursor.count)
            while (cursor.moveToNext()) out += map(row)
            return out
        }
    }

    override fun <T> transaction(block: () -> T): T {
        db.beginTransaction()
        try {
            val result = block()
            db.setTransactionSuccessful()
            return result
        } finally {
            db.endTransaction()
        }
    }

    private class CursorRow(private val c: Cursor) : SqlRow {
        private fun index(column: String): Int = c.getColumnIndex(column).also { require(it >= 0) { "no column $column" } }
        override fun string(column: String): String? = index(column).let { if (c.isNull(it)) null else c.getString(it) }
        override fun long(column: String): Long? = index(column).let { if (c.isNull(it)) null else c.getLong(it) }
        override fun double(column: String): Double? = index(column).let { if (c.isNull(it)) null else c.getDouble(it) }
        override fun has(column: String): Boolean = c.getColumnIndex(column) >= 0
        override fun stringAt(index: Int): String? = if (c.isNull(index)) null else c.getString(index)
        override fun longAt(index: Int): Long? = if (c.isNull(index)) null else c.getLong(index)
    }

    companion object {
        const val FILE_NAME = "kelime.sqlite"

        /** Opens (creating if needed) the app database and applies pending migrations. */
        fun open(file: File): AndroidSqlDb {
            file.parentFile?.mkdirs()
            val raw = SQLiteDatabase.openOrCreateDatabase(file, null)
            raw.enableWriteAheadLogging()
            raw.setForeignKeyConstraintsEnabled(true)
            return AndroidSqlDb(raw).also { Migrations.migrate(it) }
        }
    }
}
