package com.enesseval.kilitkelime.ui.games

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.games.GameResults
import com.enesseval.kilitkelime.core.games.GameWords
import com.enesseval.kilitkelime.core.games.GapFill
import com.enesseval.kilitkelime.core.games.GapFillGame
import com.enesseval.kilitkelime.core.games.SentenceCheck
import com.enesseval.kilitkelime.core.games.SentenceGame
import com.enesseval.kilitkelime.core.games.SentenceTokens
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.word.ShareCard
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

/** A word card of Cümle Kur: below (to pick) or in the row (to take back). */
@Composable
private fun WordTile(text: String, tint: Tint, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = Palette.current
    val (bg, border, ink) = when (tint) {
        Tint.PLAIN -> Triple(c.surface, c.line, c.ink)
        Tint.PICKED -> Triple(c.accentSoft, c.accent, c.ink)
        Tint.RIGHT -> Triple(c.greenBackground, c.green, c.greenInk)
        Tint.WRONG -> Triple(c.amberBackground, c.amber, c.amberInk)
    }
    Box(
        modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).background(bg).border(if (tint == Tint.PLAIN) 1.dp else 2.dp, border, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) { Text(text, style = KelimeType.english(19.sp), color = ink) }
}

private enum class Tint { PLAIN, PICKED, RIGHT, WRONG }

/**
 * Cümle Kur (docs/V1_2_PLAN.md §4a): the Turkish sentence on top, the English words as cards below;
 * tapping builds the sentence in the row above. "Kontrol et": right goes green and the next sentence
 * comes; wrong shakes the misplaced cards and gives one more try; a second miss shows the sentence.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SentenceScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    var game by remember { mutableStateOf<SentenceGame?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var round by remember { mutableIntStateOf(0) }
    var version by remember { mutableIntStateOf(0) }
    var seconds by remember { mutableIntStateOf(0) }
    var wrongPlaces by remember { mutableStateOf(setOf<Int>()) }
    var finished by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    val shake = remember { Animatable(0f) }

    LaunchedEffect(round) {
        val rng = SeededGenerator(Random.nextLong().toULong())
        val pool = app.model.read { db -> GameWords.pick(db, rng, SentenceGame.POOL, app.model.clock.today, SentenceTokens::usable) }
        val g = SentenceGame(pool, rng)
        game = g.takeIf { it.items.size >= 3 }
        wrongPlaces = emptySet(); seconds = 0; finished = false; busy = false; version++; loaded = true
    }
    val g = game
    @Suppress("UNUSED_VARIABLE") val v = version
    LaunchedEffect(g, finished) { while (g != null && !finished) { delay(1000); seconds++ } }
    LaunchedEffect(wrongPlaces) {
        if (wrongPlaces.isNotEmpty()) {
            for (x in listOf(7f, -7f, 7f, -7f, 0f)) shake.animateTo(x, tween(80))
            delay(300)
            wrongPlaces = emptySet()
        }
    }

    GameFrame("Cümle Kur", trailing = {
        if (g != null && !finished) Text("${minOf(g.index + 1, g.items.size)}/${g.items.size}", style = KelimeType.ui(14.sp, FontWeight.Bold), color = c.ink2)
    }) {
        if (!loaded) return@GameFrame
        if (g == null) {
            NotEnoughWords()
            return@GameFrame
        }
        if (finished) {
            val score = g.firstTryCount
            GameResult(
                title = "Tur bitti",
                headline = "$score / ${g.items.size} doğru",
                stats = listOf("süre" to time(seconds), "zorlandığın" to "${g.failedCards.size}"),
                words = g.failedCards,
                wordsTitle = "Widget'ında daha sık görünecek",
                onAgain = { round++ },
                onClose = { router.back() },
                share = ShareCard.Content.Game("CÜMLE KUR", "$score / ${g.items.size} doğru", time(seconds), g.firstTryCards),
                sentences = g.items.map { SentenceTokens.sentence(it.tokens) to it.card.exampleTR },
            )
            return@GameFrame
        }
        val item = g.current ?: return@GameFrame

        fun advance() {
            g.next()
            wrongPlaces = emptySet()
            busy = false
            version++
            if (g.isFinished) {
                finished = true
                val score = g.firstTryCount
                val secs = seconds
                scope.launch {
                    app.model.studied("sentence", Game.SENTENCE.source) { db -> g.record(secs, app.model.clock, db) }
                    Analytics.signal(Game.SENTENCE.signal, mapOf("score" to "$score", "seconds" to "$secs"))
                }
            }
        }

        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text(item.card.exampleTR, style = KelimeType.ui(20.sp, FontWeight.Medium), color = c.ink)
            // The row being built; a shown answer replaces it.
            Column(
                Modifier.fillMaxWidth().heightIn(min = 120.dp).clip(RoundedCornerShape(16.dp)).background(c.paper)
                    .border(1.dp, if (g.solved) c.green else c.line, RoundedCornerShape(16.dp)).padding(12.dp),
            ) {
                if (g.revealed) {
                    Text("Doğrusu", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.amberInk)
                    Text(SentenceTokens.sentence(item.tokens), style = KelimeType.english(22.sp), color = c.ink, modifier = Modifier.padding(top = 4.dp))
                } else {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        g.row.forEachIndexed { place, tile ->
                            val tint = when {
                                g.solved -> Tint.RIGHT
                                place in wrongPlaces -> Tint.WRONG
                                else -> Tint.PICKED
                            }
                            WordTile(
                                SentenceTokens.shown(item.tileText(tile), place), tint,
                                if (place in wrongPlaces) Modifier.offset { IntOffset(shake.value.dp.roundToPx(), 0) } else Modifier,
                            ) {
                                if (!busy) { g.remove(place); wrongPlaces = emptySet(); version++ }
                            }
                        }
                    }
                    if (g.row.isEmpty()) Text("Kartlara dokunarak cümleyi kur", style = KelimeType.ui(14.sp), color = c.ink2)
                }
            }
            // The cards left to pick, shuffled.
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                item.tileOrder.indices.forEach { tile ->
                    if (!g.placed(tile)) {
                        WordTile(item.tileText(tile), Tint.PLAIN) { if (!busy && !g.solved && !g.revealed) { g.place(tile); version++ } }
                    }
                }
            }
            if (g.revealed) {
                PrimaryButton(if (g.index + 1 >= g.items.size) "Bitir" else "Sıradaki cümle", height = 52.dp) { advance() }
            } else {
                Box(Modifier.fillMaxWidth().alpha(if (g.canCheck && !busy) 1f else 0.45f)) {
                    PrimaryButton("Kontrol et", height = 52.dp) {
                        if (!g.canCheck || busy) return@PrimaryButton
                        when (val result = g.check()) {
                            SentenceCheck.Correct -> {
                                haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                                busy = true
                                version++
                                scope.launch { delay(800); advance() }
                            }
                            is SentenceCheck.Wrong -> {
                                haptics.performHapticFeedback(HapticFeedbackType.Reject)
                                wrongPlaces = result.wrongPlaces
                                version++
                            }
                            SentenceCheck.Revealed -> {
                                haptics.performHapticFeedback(HapticFeedbackType.Reject)
                                version++
                            }
                            null -> {}
                        }
                    }
                }
            }
        }
    }
}

/**
 * Boşluğu Doldur (docs/V1_2_PLAN.md §4b): a 60-second round. The sentence with one word blanked, its
 * Turkish translation small underneath, four choices. Right goes green and the next comes; wrong shows
 * the right word green and moves on after a second. The best score is kept.
 */
@Composable
fun GapFillScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val haptics = LocalHapticFeedback.current
    var game by remember { mutableStateOf<GapFillGame?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var round by remember { mutableIntStateOf(0) }
    var version by remember { mutableIntStateOf(0) }
    var left by remember { mutableIntStateOf(GapFillGame.SECONDS) }
    var started by remember { mutableStateOf(false) }
    var finished by remember { mutableStateOf(false) }
    var best by remember { mutableIntStateOf(0) }
    var picked by remember { mutableStateOf<Int?>(null) }

    LaunchedEffect(round) {
        val rng = SeededGenerator(Random.nextLong().toULong())
        val questions = app.model.read { db ->
            GapFill.questions(db, GameWords.pick(db, rng, GapFillGame.POOL, app.model.clock.today, GapFill::usable), rng)
        }
        best = app.model.read { db -> GameResults.best(Game.GAP_FILL, db) }
        game = if (questions.size >= 3) GapFillGame(questions) else null
        picked = null; left = GapFillGame.SECONDS; finished = false; loaded = true; version++
    }
    val g = game
    @Suppress("UNUSED_VARIABLE") val v = version
    LaunchedEffect(g, started, finished) {
        if (!started || g == null) return@LaunchedEffect
        while (!finished && left > 0 && !g.isEmpty) { delay(1000); left-- }
        if (!finished) {
            finished = true
            val secs = GapFillGame.SECONDS - left
            // Launched on the model's scope: changing `finished` restarts this effect and would cancel the saving.
            app.model.scope.launch {
                app.model.studied("gapfill", Game.GAP_FILL.source) { db -> g.record(secs, app.model.clock, db) }
                Analytics.signal(Game.GAP_FILL.signal, mapOf("score" to "${g.score}", "seconds" to "$secs"))
            }
        }
    }

    GameFrame("Boşluğu Doldur", trailing = {
        Text("$left", style = KelimeType.ui(15.sp, FontWeight.Bold), color = if (left <= 10 && started && !finished) c.amberInk else c.ink2)
    }) {
        if (!loaded) return@GameFrame
        if (g == null) {
            NotEnoughWords()
            return@GameFrame
        }
        if (!started) {
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(Modifier.weight(1f))
                Text("60 saniye", style = KelimeType.english(48.sp), color = c.ink)
                Text(
                    "Cümledeki boşluğa uyan kelimeyi seç. Ne kadar çok doğru, o kadar çok puan.",
                    style = KelimeType.ui(15.sp), color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp),
                )
                if (best > 0) Text("En iyi skorun: $best", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.greenInk)
                Box(Modifier.weight(1f))
                Box(Modifier.padding(horizontal = 20.dp).padding(bottom = 16.dp)) { PrimaryButton("Başla", height = 52.dp) { started = true } }
            }
            return@GameFrame
        }
        if (finished) {
            val answered = g.answered
            GameResult(
                title = if (g.score >= best && g.score > 0) "Yeni rekor!" else "Süre doldu",
                headline = "${g.score} doğru",
                stats = listOf("en iyi" to "${maxOf(best, g.score)}", "zorlandığın" to "${g.missedCards.size}"),
                words = g.missedCards,
                wordsTitle = "Widget'ında daha sık görünecek",
                onAgain = { round++; started = true },
                onClose = { router.back() },
                share = ShareCard.Content.Game("BOŞLUĞU DOLDUR", "${g.score} doğru", "60 saniyede · $answered soru", g.questions.take(g.answered).map { it.card }.filter { q -> g.missedCards.none { it.id == q.id } }),
            )
            return@GameFrame
        }
        val q = g.current ?: return@GameFrame
        Column(Modifier.fillMaxSize().padding(horizontal = 20.dp).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Text("${g.score} doğru", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(q.sentence, style = KelimeType.english(26.sp), color = c.ink)
                Text(q.translation, style = KelimeType.ui(13.sp), color = c.ink2.copy(alpha = 0.7f))
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                q.options.forEachIndexed { i, option ->
                    val chosen = picked
                    val tint = when {
                        chosen == null -> Tint.PLAIN
                        i == q.answerIndex -> Tint.RIGHT
                        i == chosen -> Tint.WRONG
                        else -> Tint.PLAIN
                    }
                    WordTile(
                        (if (tint == Tint.RIGHT) "✓ " else if (tint == Tint.WRONG) "✕ " else "") + option, tint,
                        Modifier.fillMaxWidth().heightIn(min = 56.dp),
                    ) {
                        if (picked != null) return@WordTile
                        picked = i
                        val right = g.answer(i)
                        haptics.performHapticFeedback(if (right) HapticFeedbackType.Confirm else HapticFeedbackType.Reject)
                        version++
                    }
                }
            }
        }
        // After an answer: right moves on at once (a short green flash), wrong after 1 s with the right word shown.
        val chosen = picked
        LaunchedEffect(chosen, q) {
            if (chosen == null) return@LaunchedEffect
            delay(if (chosen == q.answerIndex) 350 else 1000)
            g.next()
            picked = null
            version++
        }
    }
}
