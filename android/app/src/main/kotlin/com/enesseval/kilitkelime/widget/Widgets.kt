package com.enesseval.kilitkelime.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.RowScope
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontFamily
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.LearningState
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.core.model.WidgetThemeID
import com.enesseval.kilitkelime.core.widgets.WidgetActions
import com.enesseval.kilitkelime.core.widgets.WidgetLog
import com.enesseval.kilitkelime.core.widgets.WidgetLogEntry
import com.enesseval.kilitkelime.core.widgets.WidgetSnapshot
import com.enesseval.kilitkelime.core.widgets.WidgetTimelineBuilder
import java.util.concurrent.TimeUnit

/** Updates every Glance widget; called by LockScreenUpdater after each change and slot. */
object Widgets {
    suspend fun updateAll(context: Context) {
        runCatching { CardWidget().updateAll(context) }
        runCatching { QuizWidget().updateAll(context) }
        runCatching { LargeWidget().updateAll(context) }
    }
}

/** Widget colours per theme (WidgetThemes.swift), light and dark. */
internal class WidgetColors(val background: ColorProvider, val ink: ColorProvider, val ink2: ColorProvider, val chip: ColorProvider, val word: ColorProvider)

internal fun colors(theme: WidgetThemeID): WidgetColors {
    fun c(light: Long, dark: Long) = ColorProvider(day = Color(light), night = Color(dark))
    return when (theme) {
        WidgetThemeID.PAPER -> WidgetColors(c(0xFFFBF9F5, 0xFF1C1B19), c(0xFF1B1916, 0xFFF2EEE7), c(0xFF6A6359, 0xFFA39C91), c(0xFFEAE6DE, 0xFF2A2825), c(0xFF1B1916, 0xFFF2EEE7))
        WidgetThemeID.INK -> WidgetColors(c(0xFF000000, 0xFF000000), c(0xFFFFFFFF, 0xFFFFFFFF), c(0xFF9B958C, 0xFF9B958C), c(0xFF1F1E1C, 0xFF1F1E1C), c(0xFFFFFFFF, 0xFFFFFFFF))
        WidgetThemeID.GLASS -> WidgetColors(c(0xFFDCE4EC, 0xFF27303A), c(0xFF13202D, 0xFFEEF3F8), c(0xFF5A6A7B, 0xFFA8B5C3), c(0xFFC9D3DE, 0xFF36414D), c(0xFF13202D, 0xFFEEF3F8))
        WidgetThemeID.EMBER -> WidgetColors(c(0xFF2B1B15, 0xFF2B1B15), c(0xFFF7EBE2, 0xFFF7EBE2), c(0xFFC6A999, 0xFFC6A999), c(0xFF3E2A21, 0xFF3E2A21), c(0xFFF29155, 0xFFF29155))
        WidgetThemeID.MONO -> WidgetColors(c(0xFFFFFFFF, 0xFF0B0B0B), c(0xFF0B0B0B, 0xFFFFFFFF), c(0xFF6B6B6B, 0xFF9A9A9A), c(0xFFEDEDED, 0xFF222222), c(0xFF0B0B0B, 0xFFFFFFFF))
    }
}

private val amber = ColorProvider(day = Color(0xFFE49839), night = Color(0xFFEEAC53))
private val amberBg = ColorProvider(day = Color(0xFFFFECCD), night = Color(0xFF442A08))
private val amberInk = ColorProvider(day = Color(0xFF915114), night = Color(0xFFFBC77C))
private val green = ColorProvider(day = Color(0xFF50986B), night = Color(0xFF75BE8F))
private val greenBg = ColorProvider(day = Color(0xFFE0F5E6), night = Color(0xFF1A3123))
private val greenInk = ColorProvider(day = Color(0xFF285F3F), night = Color(0xFFA1DBB4))

internal fun openWord(context: Context, card: Card, snapshot: WidgetSnapshot, source: String) = actionStartActivity(
    Intent(Intent.ACTION_VIEW, Uri.parse("kelime://word/${card.id}?src=$source&slot=${snapshot.slotStart.epochSecond}"), context, MainActivity::class.java),
)

internal fun openPuzzle(context: Context) =
    actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("kelime://puzzle"), context, MainActivity::class.java))

internal fun openApp(context: Context) = actionStartActivity(Intent(context, MainActivity::class.java))

private suspend fun load(context: Context, mode: WidgetMode? = null): WidgetSnapshot? {
    val app = context.applicationContext as KilitKelimeApp
    return runCatching { app.model.read { db -> WidgetTimelineBuilder.current(db, app.model.clock, SystemRandom(), mode) } }.getOrNull()
}

@Composable
private fun Empty(context: Context, c: WidgetColors) {
    Column(
        modifier = GlanceModifier.fillMaxSize().background(c.background).padding(14.dp).clickable(openApp(context)),
        verticalAlignment = Alignment.Bottom,
    ) {
        Text("Kelimelerini görmek için uygulamayı bir kez aç", style = TextStyle(color = c.ink, fontSize = 14.sp))
    }
}

@Composable
private fun StateDot(state: LearningState) {
    val color = when (state) {
        LearningState.NEW -> null
        LearningState.STRUGGLING -> amber
        LearningState.LEARNED -> green
    }
    Box(modifier = GlanceModifier.size(10.dp).cornerRadius(5.dp).background(color ?: ColorProvider(Color(0x33888888)))) {}
}

private val serif = FontFamily.Serif

// ---------------------------------------------------------------------------------------------
// Kart (small and medium)

class CardWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = load(context, WidgetMode.CARD)
        provideContent { CardContent(context, snapshot) }
    }

    @Composable
    private fun CardContent(context: Context, snapshot: WidgetSnapshot?) {
        val c = colors(snapshot?.theme ?: WidgetThemeID.PAPER)
        val card = snapshot?.card ?: return Empty(context, c)
        val size = androidx.glance.LocalSize.current
        val medium = size.width >= 220.dp
        Column(
            modifier = GlanceModifier.fillMaxSize().background(c.background).cornerRadius(22.dp).padding(16.dp)
                .clickable(openWord(context, card, snapshot, "card")),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = GlanceModifier.fillMaxWidth()) {
                Text(card.level.raw, style = TextStyle(color = c.ink2, fontSize = 11.sp, fontWeight = FontWeight.Bold))
                Spacer(GlanceModifier.defaultWeight())
                StateDot(snapshot.state)
            }
            Spacer(GlanceModifier.defaultWeight())
            Text(
                card.word,
                maxLines = if (card.isPhrase) 2 else 1,
                style = TextStyle(color = c.word, fontSize = wordSize(card).sp, fontFamily = serif),
            )
            Text(
                if (medium) "${card.pos.label}  ${card.meaning}" else card.meaning,
                maxLines = 2,
                style = TextStyle(color = c.ink, fontSize = 14.sp),
            )
            if (medium) {
                Spacer(GlanceModifier.height(10.dp))
                Row(modifier = GlanceModifier.fillMaxWidth()) {
                    ActionButton("Biliyorum", greenBg, greenInk, actionRunCallback<MarkAction>(actionParametersOf(MarkAction.card to card.id, MarkAction.kind to "known")))
                    Spacer(GlanceModifier.width(8.dp))
                    ActionButton("Zorlanıyorum", amberBg, amberInk, actionRunCallback<MarkAction>(actionParametersOf(MarkAction.card to card.id, MarkAction.kind to "struggling")))
                }
            }
        }
    }

    private fun wordSize(card: Card): Int = when {
        card.isPhrase -> 21
        card.word.length <= 9 -> 32
        card.word.length <= 12 -> 26
        else -> 21
    }
}

@Composable
private fun RowScope.ActionButton(title: String, background: ColorProvider, ink: ColorProvider, action: androidx.glance.action.Action) {
    Box(
        modifier = GlanceModifier.defaultWeight().height(40.dp).cornerRadius(12.dp).background(background).clickable(action),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = TextStyle(color = ink, fontSize = 14.sp, fontWeight = FontWeight.Medium))
    }
}

class CardWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CardWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        com.enesseval.kilitkelime.analytics.WidgetUsage.check(context)
    }
}

class MarkAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val cardID = parameters[card] ?: return
        val known = parameters[kind] == "known"
        val app = context.applicationContext as KilitKelimeApp
        app.model.write("widget-${parameters[kind]}") { db ->
            if (known) WidgetActions.markKnown(cardID, db, app.model.clock) else WidgetActions.markStruggling(cardID, db, app.model.clock)
            WidgetLog.recordTap("card", cardID, null, db, app.model.clock, WidgetLogEntry.Kind.BUTTON, if (known) "Biliyorum" else "Zorlanıyorum")
        }
    }

    companion object {
        val card = ActionParameters.Key<String>("card")
        val kind = ActionParameters.Key<String>("kind")
    }
}

// ---------------------------------------------------------------------------------------------
// Hangisi? (medium quiz). A result stays for a minute, then the next question comes.

class QuizWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val app = context.applicationContext as KilitKelimeApp
        val snapshot = runCatching {
            app.model.read { db ->
                val all = WidgetTimelineBuilder.quiz(db, app.model.clock, SystemRandom())
                all.lastOrNull { it.date <= app.model.clock.now } ?: all.firstOrNull()
            }
        }.getOrNull()
        provideContent { QuizContent(context, snapshot) }
    }

    @Composable
    private fun QuizContent(context: Context, snapshot: WidgetSnapshot?) {
        val c = colors(snapshot?.theme ?: WidgetThemeID.PAPER)
        val card = snapshot?.card ?: return Empty(context, c)
        val answer = snapshot.quizAnswer
        Column(modifier = GlanceModifier.fillMaxSize().background(c.background).cornerRadius(22.dp).padding(16.dp)) {
            if (answer == null) {
                Text("HANGİSİ?", style = TextStyle(color = c.ink2, fontSize = 12.sp, fontWeight = FontWeight.Bold))
                Text(card.meaning, maxLines = 2, style = TextStyle(color = c.ink, fontSize = 22.sp, fontWeight = FontWeight.Medium))
                Spacer(GlanceModifier.defaultWeight())
                Row(modifier = GlanceModifier.fillMaxWidth()) {
                    snapshot.quizOptions.forEachIndexed { i, option ->
                        if (i > 0) Spacer(GlanceModifier.width(8.dp))
                        Box(
                            modifier = GlanceModifier.defaultWeight().height(48.dp).cornerRadius(12.dp).background(c.chip)
                                .clickable(actionRunCallback<QuizAnswerAction>(actionParametersOf(QuizAnswerAction.card to card.id, QuizAnswerAction.option to option))),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(option, maxLines = 1, style = TextStyle(color = c.ink, fontSize = 19.sp, fontFamily = serif))
                        }
                    }
                }
            } else if (answer == card.word) {
                Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(card.word, style = TextStyle(color = c.word, fontSize = 30.sp, fontFamily = serif))
                    Spacer(GlanceModifier.defaultWeight())
                    Text("✓ Doğru", style = TextStyle(color = greenInk, fontSize = 13.sp, fontWeight = FontWeight.Bold))
                }
                Text(card.meaning, style = TextStyle(color = c.ink2, fontSize = 14.sp))
                Spacer(GlanceModifier.defaultWeight())
                Text(card.exampleEN, maxLines = 2, style = TextStyle(color = c.ink, fontSize = 15.sp, fontFamily = serif, fontStyle = FontStyle.Italic))
                Text(card.exampleTR, maxLines = 1, style = TextStyle(color = c.ink2, fontSize = 12.sp))
            } else {
                Text("Doğru cevap", style = TextStyle(color = amberInk, fontSize = 13.sp, fontWeight = FontWeight.Medium))
                Text(card.word, style = TextStyle(color = c.word, fontSize = 30.sp, fontFamily = serif))
                Text("${card.meaning} · $answer", maxLines = 1, style = TextStyle(color = c.ink2, fontSize = 14.sp))
                Spacer(GlanceModifier.defaultWeight())
                Text("Bu kelime sık gelecek", style = TextStyle(color = amberInk, fontSize = 14.sp, fontWeight = FontWeight.Medium))
            }
        }
    }
}

class QuizWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuizWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        com.enesseval.kilitkelime.analytics.WidgetUsage.check(context)
    }
}

class QuizAnswerAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val cardID = parameters[card] ?: return
        val choice = parameters[option] ?: return
        val app = context.applicationContext as KilitKelimeApp
        app.model.write("widget-quiz") { db ->
            WidgetActions.answerQuiz(cardID, choice, db, app.model.clock)
            WidgetLog.recordTap("quiz", cardID, null, db, app.model.clock, WidgetLogEntry.Kind.BUTTON, choice)
        }
        // Next question after the result has been on screen for a minute.
        val request = OneTimeWorkRequestBuilder<QuizNextWorker>()
            .setInitialDelay(WidgetTimelineBuilder.quizResultDuration.seconds + 1, TimeUnit.SECONDS).build()
        WorkManager.getInstance(context).enqueueUniqueWork("quiz-next", ExistingWorkPolicy.REPLACE, request)
    }

    companion object {
        val card = ActionParameters.Key<String>("card")
        val option = ActionParameters.Key<String>("option")
    }
}

class QuizNextWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        QuizWidget().updateAll(applicationContext)
        return Result.success()
    }
}

// ---------------------------------------------------------------------------------------------
// Büyük: current word, today's struggling words, crossword thumbnail.

class LargeWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = load(context, WidgetMode.CARD)
        provideContent { LargeContent(context, snapshot) }
    }

    @Composable
    private fun LargeContent(context: Context, snapshot: WidgetSnapshot?) {
        val c = colors(snapshot?.theme ?: WidgetThemeID.PAPER)
        val card = snapshot?.card ?: return Empty(context, c)
        Column(modifier = GlanceModifier.fillMaxSize().background(c.background).cornerRadius(22.dp).padding(16.dp)) {
            Column(modifier = GlanceModifier.fillMaxWidth().clickable(openWord(context, card, snapshot, "large"))) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = GlanceModifier.fillMaxWidth()) {
                    Text(card.word, maxLines = 1, style = TextStyle(color = c.word, fontSize = 30.sp, fontFamily = serif))
                    Spacer(GlanceModifier.defaultWeight())
                    Text(card.level.raw, style = TextStyle(color = c.ink2, fontSize = 11.sp, fontWeight = FontWeight.Bold))
                    Spacer(GlanceModifier.width(8.dp))
                    StateDot(snapshot.state)
                }
                Text("${card.pos.label}  ${card.meaning}", maxLines = 2, style = TextStyle(color = c.ink, fontSize = 14.sp))
                Text(card.exampleEN, maxLines = 2, style = TextStyle(color = c.ink, fontSize = 14.sp, fontFamily = serif, fontStyle = FontStyle.Italic))
            }
            Spacer(GlanceModifier.height(12.dp))
            Text("BUGÜN ZORLANDIKLARIN", style = TextStyle(color = c.ink2, fontSize = 11.sp, fontWeight = FontWeight.Bold))
            Spacer(GlanceModifier.height(4.dp))
            if (snapshot.struggling.isEmpty()) {
                Text("Zorlandığın kelime yok. Bir Hızlı Tekrar ile başla.", style = TextStyle(color = c.ink2, fontSize = 14.sp))
            } else {
                for (word in snapshot.struggling.take(3)) {
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 3.dp).clickable(openWord(context, word, snapshot, "large-struggling")),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        StateDot(LearningState.STRUGGLING)
                        Spacer(GlanceModifier.width(8.dp))
                        Text(word.word, style = TextStyle(color = c.ink, fontSize = 17.sp, fontFamily = serif))
                        Spacer(GlanceModifier.width(8.dp))
                        Text(word.primaryMeaning, maxLines = 1, style = TextStyle(color = c.ink2, fontSize = 14.sp))
                    }
                }
            }
            Spacer(GlanceModifier.defaultWeight())
            Row(modifier = GlanceModifier.fillMaxWidth().clickable(openPuzzle(context)), verticalAlignment = Alignment.CenterVertically) {
                MiniGrid(snapshot.puzzleProgress?.cells ?: sampleCells, c)
                Spacer(GlanceModifier.width(12.dp))
                val p = snapshot.puzzleProgress
                Column {
                    Text("Günün Bulmacası", style = TextStyle(color = c.ink, fontSize = 14.sp, fontWeight = FontWeight.Medium))
                    Text(if (p == null) "ipuçları Türkçe" else "${p.solved}/${p.total} kelime", style = TextStyle(color = c.ink2, fontSize = 13.sp))
                }
            }
        }
    }

    @Composable
    private fun MiniGrid(cells: Map<Int, Boolean>, c: WidgetColors) {
        Column {
            for (row in 0 until 10) {
                Row {
                    for (col in 0 until 8) {
                        val solved = cells[row * 8 + col]
                        val color = when (solved) {
                            null -> ColorProvider(Color.Transparent)
                            false -> c.chip
                            true -> green
                        }
                        Box(modifier = GlanceModifier.size(5.dp).background(color)) {}
                        if (col < 7) Spacer(GlanceModifier.width(1.dp))
                    }
                }
                if (row < 9) Spacer(GlanceModifier.height(1.dp))
            }
        }
    }

    private val sampleCells: Map<Int, Boolean> = buildMap {
        fun word(r: Int, c: Int, length: Int, across: Boolean) {
            for (i in 0 until length) put((if (across) r else r + i) * 8 + (if (across) c + i else c), false)
        }
        word(0, 2, 6, true); word(0, 3, 7, false); word(3, 0, 8, true); word(3, 5, 7, false); word(9, 1, 7, true)
    }
}

class LargeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = LargeWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        com.enesseval.kilitkelime.analytics.WidgetUsage.check(context)
    }
}
