package com.enesseval.kilitkelime.core.db

/**
 * Numbered schema migrations, a 1:1 port of `Migrations.swift` (v1–v6) plus v7 for the 1.1
 * tables. Never edit a migration that has shipped; add a new one.
 *
 * Dates are epoch milliseconds (INTEGER); local days are `YYYY-MM-DD` text.
 * The applied version is kept in `PRAGMA user_version`.
 */
object Migrations {
    val all: List<List<String>> = listOf(
        // v1
        listOf(
            """CREATE TABLE card (
                id TEXT PRIMARY KEY NOT NULL,
                word TEXT NOT NULL,
                pos TEXT NOT NULL,
                level TEXT NOT NULL,
                tr TEXT NOT NULL,
                example_en TEXT NOT NULL,
                example_tr TEXT NOT NULL)""",
            "CREATE INDEX card_on_level ON card(level)",
            """CREATE TABLE card_deck (
                card_id TEXT NOT NULL REFERENCES card(id) ON DELETE CASCADE,
                deck TEXT NOT NULL,
                PRIMARY KEY (card_id, deck))""",
            "CREATE INDEX card_deck_on_deck ON card_deck(deck)",
            // No foreign key to `card`: progress must survive content updates.
            """CREATE TABLE card_state (
                card_id TEXT PRIMARY KEY NOT NULL,
                state TEXT NOT NULL DEFAULT 'new',
                correct_streak INTEGER NOT NULL DEFAULT 0,
                last_shown_at INTEGER,
                last_answered_on TEXT,
                times_shown INTEGER NOT NULL DEFAULT 0,
                favorite INTEGER NOT NULL DEFAULT 0)""",
            "CREATE INDEX card_state_on_state ON card_state(state)",
            """CREATE TABLE widget_queue (
                slot_start INTEGER PRIMARY KEY NOT NULL,
                card_id TEXT NOT NULL,
                quiz_options TEXT NOT NULL,
                quiz_answer TEXT)""",
            "CREATE TABLE settings (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)",
            """CREATE TABLE review_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                card_id TEXT NOT NULL,
                answered_at INTEGER NOT NULL,
                answered_on TEXT NOT NULL,
                correct INTEGER NOT NULL,
                source TEXT NOT NULL,
                session_id TEXT)""",
            "CREATE INDEX review_log_on_card_id ON review_log(card_id)",
            "CREATE INDEX review_log_on_answered_on ON review_log(answered_on)",
            """CREATE TABLE puzzle_progress (
                puzzle_key TEXT PRIMARY KEY NOT NULL,
                cells TEXT NOT NULL,
                hints_used INTEGER NOT NULL DEFAULT 0,
                completed_at INTEGER,
                seconds INTEGER NOT NULL DEFAULT 0)""",
        ),
        // v2: marks queue slots already counted in card_state.
        listOf("ALTER TABLE widget_queue ADD COLUMN counted INTEGER NOT NULL DEFAULT 0"),
        // v3: diagnostics of what the lock screen and widgets showed (WidgetLog).
        listOf(
            """CREATE TABLE widget_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                at INTEGER NOT NULL,
                kind TEXT NOT NULL,
                source TEXT NOT NULL,
                detail TEXT NOT NULL DEFAULT '',
                shown_card_id TEXT,
                shown_slot INTEGER,
                expected_card_id TEXT,
                expected_slot INTEGER,
                reload_at INTEGER)""",
            "CREATE INDEX widget_log_on_at ON widget_log(at)",
        ),
        // v4: course content.
        listOf(
            "ALTER TABLE card ADD COLUMN note TEXT",
            "ALTER TABLE card ADD COLUMN senses TEXT",
            """CREATE TABLE unit (
                id TEXT PRIMARY KEY NOT NULL,
                level TEXT NOT NULL,
                title TEXT NOT NULL,
                goal TEXT NOT NULL,
                placement TEXT NOT NULL,
                position INTEGER NOT NULL,
                stories TEXT NOT NULL)""",
            "CREATE INDEX unit_on_level ON unit(level)",
            """CREATE TABLE unit_card (
                unit_id TEXT NOT NULL REFERENCES unit(id) ON DELETE CASCADE,
                card_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                PRIMARY KEY (unit_id, card_id))""",
            "CREATE INDEX unit_card_on_card_id ON unit_card(card_id)",
        ),
        // v5: the learner's own lists.
        listOf(
            """CREATE TABLE user_list (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                enabled INTEGER NOT NULL DEFAULT 1,
                imported INTEGER NOT NULL DEFAULT 0)""",
            """CREATE TABLE user_list_card (
                list_id TEXT NOT NULL REFERENCES user_list(id) ON DELETE CASCADE,
                card_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                PRIMARY KEY (list_id, card_id))""",
            "CREATE INDEX user_list_card_on_card_id ON user_list_card(card_id)",
        ),
        // v6: account sync.
        listOf(
            "ALTER TABLE user_list ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private'",
            "ALTER TABLE user_list ADD COLUMN updated_at INTEGER",
            "ALTER TABLE user_list ADD COLUMN synced_at INTEGER",
            "ALTER TABLE user_list ADD COLUMN source_id TEXT",
            "CREATE TABLE user_list_deleted (id TEXT PRIMARY KEY NOT NULL)",
        ),
        // v7 (Android 1.1): days studied for the streak, and game results.
        listOf(
            "CREATE TABLE streak_day (day TEXT PRIMARY KEY NOT NULL)",
            "INSERT OR IGNORE INTO streak_day (day) SELECT DISTINCT answered_on FROM review_log",
            """CREATE TABLE game_result (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                game TEXT NOT NULL,
                day TEXT NOT NULL,
                score INTEGER NOT NULL,
                total INTEGER NOT NULL,
                seconds INTEGER NOT NULL DEFAULT 0,
                finished_at INTEGER NOT NULL)""",
            "CREATE INDEX game_result_on_day ON game_result(day)",
        ),
    )

    val latest: Int get() = all.size

    /** Applies migrations after [from] (the stored user_version). */
    fun migrate(db: SqlDb, from: Int) {
        for (version in (from + 1)..latest) {
            db.transaction {
                for (statement in all[version - 1]) db.execute(statement)
                db.execute("PRAGMA user_version = $version")
            }
        }
    }

    /** Reads `PRAGMA user_version` and applies what is missing. */
    fun migrate(db: SqlDb) {
        migrate(db, db.int("PRAGMA user_version"))
    }
}
