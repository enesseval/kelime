package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.db.Sql
import com.enesseval.kilitkelime.core.db.SqlDb

/** How often the widget word changes. */
enum class RotationInterval(val minutes: Int) {
    THIRTY_MINUTES(30), ONE_HOUR(60), THREE_HOURS(180), DAILY(1440);

    val seconds: Long get() = minutes * 60L

    /** Without Pro every rotation is 3 hours. */
    fun effective(isPro: Boolean): RotationInterval = if (isPro) this else DEFAULT

    /** "günde X'e kadar": how many words a day this interval can show. */
    val perDay: Int get() = 1440 / minutes

    companion object {
        val DEFAULT = THREE_HOURS
        fun fromMinutes(minutes: Int?): RotationInterval? = entries.firstOrNull { it.minutes == minutes }
    }
}

/** Display style of the lock-screen word (widget mode on iOS). */
enum class WidgetMode(val raw: String) {
    CARD("card"), DICTIONARY("dictionary"), WORD_AND_SENTENCE("wordAndSentence"), SENTENCE("sentence"), SELF_TEST("selfTest");

    val label: String
        get() = when (this) {
            CARD -> "Kart"
            DICTIONARY -> "Sözlük"
            WORD_AND_SENTENCE -> "Kelime ve cümle"
            SENTENCE -> "Örnek cümle"
            SELF_TEST -> "Kendini sına"
        }

    val detail: String
        get() = when (this) {
            CARD -> "Büyük kelime, altında türü ve Türkçe anlamı"
            DICTIONARY -> "Arka plansız, sözlük gibi: KELİME (tür) ve anlamı"
            WORD_AND_SENTENCE -> "Kelime ve İngilizce örnek cümlesi"
            SENTENCE -> "İngilizce cümle, altında Türkçesi"
            SELF_TEST -> "Önce anlam ve ilk harf, biraz sonra cevap"
        }

    companion object {
        fun fromRaw(raw: String?): WidgetMode? = entries.firstOrNull { it.raw == raw }
    }
}

/** Which cards the widget shows: words, phrases or both. */
enum class WidgetContent(val raw: String) {
    ALL("all"), WORDS("words"), PHRASES("phrases");

    val label: String
        get() = when (this) {
            ALL -> "Kelime ve kalıp"
            WORDS -> "Sadece kelime"
            PHRASES -> "Sadece kalıp"
        }

    /** SQL condition on `card c`, or null for everything. */
    val condition: Sql?
        get() = when (this) {
            ALL -> null
            WORDS -> Sql("c.pos <> ?", listOf(PartOfSpeech.PHRASE.raw))
            PHRASES -> Sql("c.pos = ?", listOf(PartOfSpeech.PHRASE.raw))
        }

    companion object {
        fun fromRaw(raw: String?): WidgetContent? = entries.firstOrNull { it.raw == raw }
    }
}

/** Home-widget themes. Paper is free; the rest are Pro. */
enum class WidgetThemeID(val raw: String) {
    PAPER("paper"), INK("ink"), GLASS("glass"), EMBER("ember"), MONO("mono");

    val isPro: Boolean get() = this != PAPER

    val title: String
        get() = when (this) {
            PAPER -> "Kâğıt"
            INK -> "Mürekkep"
            GLASS -> "Cam"
            EMBER -> "Kor"
            MONO -> "Yalın"
        }

    fun effective(isPro: Boolean): WidgetThemeID = if (this.isPro && !isPro) PAPER else this

    companion object {
        fun fromRaw(raw: String?): WidgetThemeID? = entries.firstOrNull { it.raw == raw }
    }
}

/** The settings the scheduler and widgets need, with defaults applied. */
data class Preferences(
    val level: CEFRLevel = CEFRLevel.B1,
    val enabledDecks: List<DeckID> = DeckID.basicDecks,
    val rotationInterval: RotationInterval = RotationInterval.DEFAULT,
    val defaultWidgetMode: WidgetMode = WidgetMode.CARD,
    val theme: WidgetThemeID = WidgetThemeID.PAPER,
    val widgetContent: WidgetContent = WidgetContent.ALL,
    val isPro: Boolean = false,
) {
    val entitledDecks: List<DeckID> get() = DeckID.entitled(enabledDecks)
    val effectiveRotation: RotationInterval get() = rotationInterval.effective(isPro)
    val effectiveTheme: WidgetThemeID get() = theme.effective(isPro)

    fun save(db: SqlDb) {
        Settings.set(db, SettingKey.LEVEL, level.raw)
        Settings.set(db, SettingKey.ENABLED_DECKS, enabledDecks.joinToString(",") { it.raw })
        Settings.setInt(db, SettingKey.ROTATION_INTERVAL, rotationInterval.minutes)
        Settings.set(db, SettingKey.DEFAULT_WIDGET_MODE, defaultWidgetMode.raw)
        Settings.set(db, SettingKey.THEME, theme.raw)
        Settings.set(db, SettingKey.WIDGET_CONTENT, widgetContent.raw)
        Settings.setBool(db, SettingKey.IS_PRO, isPro)
    }

    companion object {
        fun load(db: SqlDb): Preferences {
            var p = Preferences()
            CEFRLevel.fromRaw(Settings.string(db, SettingKey.LEVEL))?.let { p = p.copy(level = it) }
            Settings.string(db, SettingKey.ENABLED_DECKS)?.let { raw ->
                p = p.copy(enabledDecks = raw.split(",").mapNotNull(DeckID::fromRaw))
            }
            RotationInterval.fromMinutes(Settings.int(db, SettingKey.ROTATION_INTERVAL))?.let { p = p.copy(rotationInterval = it) }
            WidgetMode.fromRaw(Settings.string(db, SettingKey.DEFAULT_WIDGET_MODE))?.let { p = p.copy(defaultWidgetMode = it) }
            WidgetThemeID.fromRaw(Settings.string(db, SettingKey.THEME))?.let { p = p.copy(theme = it) }
            WidgetContent.fromRaw(Settings.string(db, SettingKey.WIDGET_CONTENT))?.let { p = p.copy(widgetContent = it) }
            return p.copy(isPro = Settings.bool(db, SettingKey.IS_PRO))
        }
    }
}
