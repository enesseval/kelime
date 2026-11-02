package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.content.CardsFile
import com.enesseval.kilitkelime.core.content.ContentCard
import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.db.Migrations
import com.enesseval.kilitkelime.core.db.SqlArgs
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.SqlRow
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.DeckTag
import com.enesseval.kilitkelime.core.model.PartOfSpeech
import java.io.File
import java.sql.Connection
import java.sql.DriverManager
import java.sql.ResultSet

/** SQLite over JDBC, running the same SQL as the app. */
class JdbcSqlDb(private val connection: Connection) : SqlDb {
    private var depth = 0

    init {
        connection.createStatement().use { it.execute("PRAGMA foreign_keys = ON") }
    }

    override fun execute(sql: String, args: List<Any?>) {
        connection.prepareStatement(sql).use { st ->
            args.forEachIndexed { i, a -> st.setObject(i + 1, SqlArgs.normalize(a)) }
            st.execute()
        }
    }

    override fun <T> query(sql: String, args: List<Any?>, map: (SqlRow) -> T): List<T> =
        connection.prepareStatement(sql).use { st ->
            args.forEachIndexed { i, a -> st.setObject(i + 1, SqlArgs.normalize(a)) }
            st.executeQuery().use { rs ->
                val row = JdbcRow(rs)
                val out = mutableListOf<T>()
                while (rs.next()) out += map(row)
                out
            }
        }

    override fun <T> transaction(block: () -> T): T {
        if (depth > 0) return block()
        connection.autoCommit = false
        depth++
        try {
            val result = block()
            connection.commit()
            return result
        } catch (e: Throwable) {
            connection.rollback()
            throw e
        } finally {
            depth--
            connection.autoCommit = true
        }
    }

    private class JdbcRow(private val rs: ResultSet) : SqlRow {
        private val names = (1..rs.metaData.columnCount).map { rs.metaData.getColumnLabel(it) }
        private fun index(column: String): Int = names.lastIndexOf(column).let { if (it < 0) error("no column $column in $names") else it + 1 }
        override fun string(column: String): String? = rs.getString(index(column))
        override fun long(column: String): Long? = rs.getLong(index(column)).takeUnless { rs.wasNull() }
        override fun double(column: String): Double? = rs.getDouble(index(column)).takeUnless { rs.wasNull() }
        override fun has(column: String) = column in names
        override fun stringAt(index: Int): String? = rs.getString(index + 1)
        override fun longAt(index: Int): Long? = rs.getLong(index + 1).takeUnless { rs.wasNull() }
    }
}

object TestSupport {
    val repoRoot: File = File(System.getProperty("kelime.repoRoot") ?: "../..")
    val bundledCards: File get() = File(repoRoot, "Content/cards.json")

    /** An empty in-memory database with the full schema. */
    fun database(): JdbcSqlDb {
        val db = JdbcSqlDb(DriverManager.getConnection("jdbc:sqlite::memory:"))
        Migrations.migrate(db)
        return db
    }

    fun card(word: String, level: CEFRLevel = CEFRLevel.B1, pos: PartOfSpeech = PartOfSpeech.ADJECTIVE, tr: List<String> = listOf("anlam")) =
        Card("${level.raw.lowercase()}-$word", word, pos, level, tr, "This is $word.", "Bu bir örnek.")

    fun cardsJSON(version: Int, cards: List<Pair<Card, List<DeckTag>>>): String =
        ContentImporter.encode(CardsFile(version, cards.map { ContentCard.of(it.first, it.second) }))

    val bundledText: String by lazy { bundledCards.readText() }

    /** A database with the bundled content and [prefs]. */
    fun bundled(prefs: com.enesseval.kilitkelime.core.model.Preferences = com.enesseval.kilitkelime.core.model.Preferences()): JdbcSqlDb {
        val db = database()
        ContentImporter.importIfNeeded(bundledText, db)
        prefs.save(db)
        return db
    }

    /** A database holding [cards] (general deck unless given). */
    fun seeded(vararg cards: Card, decks: List<DeckTag> = listOf(DeckTag.GENERAL)): JdbcSqlDb {
        val db = database()
        ContentImporter.importIfNeeded(cardsJSON(1, cards.map { it to decks }), db)
        return db
    }
}
