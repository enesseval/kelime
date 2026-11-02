package com.enesseval.kilitkelime.core.content

import com.enesseval.kilitkelime.core.db.RawValue
import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.db.SqlRow
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.db.strings
import com.enesseval.kilitkelime.core.learning.UserLists
import com.enesseval.kilitkelime.core.model.CEFRLevel
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.DeckID
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

/** A short story at the end of a unit. */
@Serializable
data class UnitStory(
    val id: String,
    val title: String,
    @SerialName("title_tr") val titleTR: String? = null,
    val lines: List<Line>,
) {
    @Serializable
    data class Line(val en: String, val tr: String)
}

@Serializable
enum class UnitPlacement(override val raw: String) : RawValue {
    @SerialName("first") FIRST("first"),
    @SerialName("any") ANY("any"),
    @SerialName("last") LAST("last");

    companion object {
        fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } ?: ANY
    }
}

/** One unit of a level's course. */
data class CurriculumUnit(
    val id: String,
    val level: CEFRLevel,
    val title: String,
    val goal: String,
    val placement: UnitPlacement,
    val position: Int,
    val stories: List<UnitStory>,
) {
    companion object {
        private val storiesSerializer = ListSerializer(UnitStory.serializer())

        fun from(row: SqlRow) = CurriculumUnit(
            id = row.requireString("id"),
            level = CEFRLevel.fromRaw(row.string("level")) ?: CEFRLevel.A1,
            title = row.requireString("title"),
            goal = row.string("goal") ?: "",
            placement = UnitPlacement.fromRaw(row.string("placement")),
            position = row.int("position") ?: 0,
            stories = row.string("stories")?.let { Json.decodeFromString(storiesSerializer, it) } ?: emptyList(),
        )

        fun encodeStories(stories: List<UnitStory>): String = Json.encodeToString(storiesSerializer, stories)

        fun fetch(db: SqlDb, id: String): CurriculumUnit? =
            db.query("SELECT * FROM unit WHERE id = ?", listOf(id), ::from).firstOrNull()
    }
}

/** A unit with the learner's progress. */
data class UnitProgress(val unit: CurriculumUnit, val total: Int, val learned: Int, val started: Boolean) {
    val id: String get() = unit.id
    val fraction: Double get() = if (total == 0) 0.0 else learned.toDouble() / total
    val isFinished: Boolean get() = total > 0 && learned == total
}

/** The learner's course at their level. */
data class CourseState(
    val level: CEFRLevel,
    val units: List<UnitProgress>,
    val currentID: String?,
    val nextLevel: CEFRLevel?,
) {
    val current: UnitProgress? get() = units.firstOrNull { it.id == currentID }
    val isComplete: Boolean get() = units.isNotEmpty() && units.all { it.isFinished }
}

/** The course: units per level, started units, their cards (port of `Curriculum.swift`). */
object Curriculum {
    /** Share of a unit's cards learned at which the next unit starts. */
    const val ADVANCE_AT = 0.8

    fun levels(db: SqlDb): List<CEFRLevel> {
        val raw = db.strings("SELECT DISTINCT level FROM unit")
        return CEFRLevel.entries.filter { it.raw in raw }
    }

    fun units(level: CEFRLevel, db: SqlDb): List<CurriculumUnit> =
        db.query("SELECT * FROM unit WHERE level = ? ORDER BY position", listOf(level), CurriculumUnit::from)

    private fun saved(db: SqlDb): List<String> =
        (Settings.string(db, SettingKey.UNITS_STARTED) ?: "").split(",").filter { it.isNotEmpty() }

    /** Started unit ids; core units always count as started. */
    fun started(db: SqlDb): Set<String> =
        saved(db).toSet() + db.strings("SELECT id FROM unit WHERE placement = ?", listOf(UnitPlacement.FIRST))

    /** Starts [unitID]: its cards join the rotation; its level deck turns on while the course is on. */
    fun start(unitID: String, db: SqlDb) {
        val unit = CurriculumUnit.fetch(db, unitID) ?: return
        val saved = saved(db).toMutableList()
        if (unitID !in saved) {
            saved.add(unitID)
            Settings.set(db, SettingKey.UNITS_STARTED, saved.joinToString(","))
        }
        val prefs = Preferences.load(db)
        val courseOn = prefs.enabledDecks.any { it.level != null }
        val nothingElse = prefs.enabledDecks.isEmpty() && !UserLists.hasEnabledLists(db)
        val deck = DeckID.forLevel(unit.level)
        if ((courseOn || nothingElse) && deck !in prefs.enabledDecks) {
            prefs.copy(enabledDecks = prefs.enabledDecks + deck).save(db)
        }
    }

    fun cards(unitID: String, db: SqlDb): List<Card> = db.query(
        "SELECT c.* FROM card c JOIN unit_card u ON u.card_id = c.id WHERE u.unit_id = ? ORDER BY u.position",
        listOf(unitID), Card::from,
    )

    fun progress(level: CEFRLevel, db: SqlDb): List<UnitProgress> {
        val started = started(db)
        return units(level, db).map { unit ->
            val (total, learned) = db.query(
                """SELECT COUNT(*) AS total, SUM(CASE WHEN s.state = 'learned' THEN 1 ELSE 0 END) AS learned
                   FROM unit_card u LEFT JOIN card_state s ON s.card_id = u.card_id WHERE u.unit_id = ?""",
                listOf(unit.id),
            ) { (it.int("total") ?: 0) to (it.int("learned") ?: 0) }.first()
            UnitProgress(unit, total, learned, unit.id in started)
        }
    }

    /** SQL condition on `card c`: cards outside the course, or in a started unit. */
    fun startedFilter(db: SqlDb): Sql {
        val started = started(db).toList()
        return Sql(
            "(NOT EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id) " +
                "OR EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id AND uc.unit_id IN ",
        ) + Sql.list(started) + "))"
    }

    /** Units in the order the learner meets them: core, any-order units, bridge. */
    fun <T> ordered(units: List<T>, unit: (T) -> CurriculumUnit): List<T> =
        units.sortedWith(compareBy<T>({ unit(it).placement.ordinal }, { unit(it).position }))

    fun state(db: SqlDb): CourseState? {
        val level = Preferences.load(db).level
        val units = ordered(progress(level, db)) { it.unit }
        if (units.isEmpty()) return null
        val stored = Settings.string(db, SettingKey.CURRENT_UNIT)
        val current = units.firstOrNull { it.id == stored && !it.isFinished }
            ?: units.firstOrNull { it.started && it.fraction < ADVANCE_AT }
            ?: units.firstOrNull { !it.started }
            ?: units.firstOrNull { !it.isFinished }
        var nextLevel: CEFRLevel? = null
        val nearlyDone = units.none { !it.started } && (current?.let { it.fraction >= ADVANCE_AT } ?: true)
        val next = CEFRLevel.entries.firstOrNull { it > level }
        if (nearlyDone && next != null && db.int("SELECT COUNT(*) FROM unit WHERE level = ?", listOf(next)) > 0) {
            nextLevel = next
        }
        return CourseState(level, units, current?.id, nextLevel)
    }

    /** Keeps the current unit started and moves on once it is nearly learned. */
    fun advance(db: SqlDb): String? {
        val state = state(db) ?: return null
        val current = state.current ?: return null
        if (!current.started) start(current.id, db)
        if (Settings.string(db, SettingKey.CURRENT_UNIT) != current.id) {
            Settings.set(db, SettingKey.CURRENT_UNIT, current.id)
        }
        val open = state.units.filter { it.id != current.id && it.fraction < ADVANCE_AT }
        if (current.fraction < ADVANCE_AT) return null
        val next = open.firstOrNull { it.started } ?: open.firstOrNull() ?: return null
        makeCurrent(next.id, db)
        return next.id
    }

    fun makeCurrent(unitID: String, db: SqlDb) {
        start(unitID, db)
        Settings.set(db, SettingKey.CURRENT_UNIT, unitID)
    }

    /** Moves the learner up to [level]; earlier units stay started. */
    fun moveOn(level: CEFRLevel, db: SqlDb) {
        val prefs = Preferences.load(db)
        val deck = DeckID.forLevel(level)
        prefs.copy(level = level, enabledDecks = if (deck in prefs.enabledDecks) prefs.enabledDecks else prefs.enabledDecks + deck).save(db)
        Settings.set(db, SettingKey.CURRENT_UNIT, null)
        advance(db)
    }

    /** Another level picked in Ayarlar: only that level's course (plus exam decks already on). */
    fun switchLevel(level: CEFRLevel, db: SqlDb) {
        val prefs = Preferences.load(db)
        val decks = DeckID.entries.filter { it.level == level || (it.tag != null && it in prefs.enabledDecks) }
        prefs.copy(level = level, enabledDecks = decks).save(db)
        Settings.set(db, SettingKey.CURRENT_UNIT, null)
        advance(db)
    }

    /** Replaces every unit (part of a content import). */
    internal fun replace(units: List<ContentUnit>, db: SqlDb) {
        db.execute("DELETE FROM unit_card")
        db.execute("DELETE FROM unit")
        for (item in units) {
            db.execute(
                "INSERT INTO unit (id, level, title, goal, placement, position, stories) VALUES (?, ?, ?, ?, ?, ?, ?)",
                listOf(item.id, item.level, item.title, item.goal, item.placement, item.position, CurriculumUnit.encodeStories(item.stories)),
            )
            item.cards.forEachIndexed { position, cardID ->
                db.execute("INSERT INTO unit_card (unit_id, card_id, position) VALUES (?, ?, ?)", listOf(item.id, cardID, position))
            }
        }
    }
}
