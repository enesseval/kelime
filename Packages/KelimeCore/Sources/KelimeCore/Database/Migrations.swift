import GRDB

/// Numbered schema migrations. Never edit a migration that has shipped; add a new one.
enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "card") { t in
                t.primaryKey("id", .text)
                t.column("word", .text).notNull()
                t.column("pos", .text).notNull()
                t.column("level", .text).notNull().indexed()
                t.column("tr", .jsonText).notNull()
                t.column("example_en", .text).notNull()
                t.column("example_tr", .text).notNull()
            }

            try db.create(table: "card_deck") { t in
                t.column("card_id", .text).notNull()
                    .references("card", onDelete: .cascade)
                t.column("deck", .text).notNull().indexed()
                t.primaryKey(["card_id", "deck"])
            }

            // No foreign key to `card`: user progress must survive content updates.
            try db.create(table: "card_state") { t in
                t.primaryKey("card_id", .text)
                t.column("state", .text).notNull().defaults(to: LearningState.new.rawValue).indexed()
                t.column("correct_streak", .integer).notNull().defaults(to: 0)
                t.column("last_shown_at", .datetime)
                t.column("last_answered_on", .text)
                t.column("times_shown", .integer).notNull().defaults(to: 0)
                t.column("favorite", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "widget_queue") { t in
                t.primaryKey("slot_start", .datetime)
                t.column("card_id", .text).notNull()
                t.column("quiz_options", .jsonText).notNull()
                t.column("quiz_answer", .text)
            }

            try db.create(table: "settings") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }

            try db.create(table: "review_log") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("card_id", .text).notNull().indexed()
                t.column("answered_at", .datetime).notNull()
                t.column("answered_on", .text).notNull().indexed()
                t.column("correct", .boolean).notNull()
                t.column("source", .text).notNull()
                t.column("session_id", .text)
            }

            try db.create(table: "puzzle_progress") { t in
                t.primaryKey("puzzle_key", .text)
                t.column("cells", .text).notNull()
                t.column("hints_used", .integer).notNull().defaults(to: 0)
                t.column("completed_at", .datetime)
                t.column("seconds", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v2") { db in
            // Marks queue slots already counted in card_state.times_shown / last_shown_at.
            try db.alter(table: "widget_queue") { t in
                t.add(column: "counted", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v3") { db in
            // Developer diagnostics: when iOS asks for a widget timeline, and which entry the
            // widget showed when it was tapped. See WidgetLog.
            try db.create(table: "widget_log") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("at", .datetime).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("source", .text).notNull()
                t.column("detail", .text).notNull().defaults(to: "")
                t.column("shown_card_id", .text)
                t.column("shown_slot", .datetime)
                t.column("expected_card_id", .text)
                t.column("expected_slot", .datetime)
                t.column("reload_at", .datetime)
            }
        }

        migrator.registerMigration("v4") { db in
            // Course content: card notes and extra senses, units with their stories, and
            // which cards belong to which unit (a card may sit in several).
            try db.alter(table: "card") { t in
                t.add(column: "note", .text)
                t.add(column: "senses", .text)
            }
            try db.create(table: "unit") { t in
                t.primaryKey("id", .text)
                t.column("level", .text).notNull().indexed()
                t.column("title", .text).notNull()
                t.column("goal", .text).notNull()
                t.column("placement", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("stories", .text).notNull()
            }
            try db.create(table: "unit_card") { t in
                t.column("unit_id", .text).notNull().references("unit", onDelete: .cascade)
                t.column("card_id", .text).notNull().indexed()
                t.column("position", .integer).notNull()
                t.primaryKey(["unit_id", "card_id"])
            }
        }

        return migrator
    }
}
