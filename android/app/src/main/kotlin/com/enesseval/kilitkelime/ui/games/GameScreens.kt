package com.enesseval.kilitkelime.ui.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.ui.draw.scale
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.geometry.Offset
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.foundation.Canvas
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseIn
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
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
import com.enesseval.kilitkelime.core.games.MatchGame
import com.enesseval.kilitkelime.core.games.WordHunt
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SeededGenerator
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.share.ShareCardSheet
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.word.ShareCard
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.random.Random

private fun time(seconds: Int) = "%d:%02d".format(seconds / 60, seconds % 60)

/**
 * Kelime Avı (docs/V1_1_PLAN.md §2a): find the hidden English words from their Turkish meanings by
 * dragging across the letters. "İlk harfi göster" lights the first letter and counts as a hint.
 */
@Composable
fun WordHuntScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    // 10 × 10, 9 × 9 under 360 dp (docs/SYNC.md).
    val size = if (LocalConfiguration.current.screenWidthDp < 360) WordHunt.SMALL_SIZE else WordHunt.SIZE
    var hunt by remember { mutableStateOf<WordHunt?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var round by remember { mutableIntStateOf(0) }
    var found by remember { mutableStateOf(setOf<String>()) }
    var hinted by remember { mutableStateOf(setOf<String>()) }
    var seconds by remember { mutableIntStateOf(0) }
    var recorded by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }

    LaunchedEffect(round) {
        // A seeded generator keeps the round reproducible (and testable).
        val rng = SeededGenerator(Random.nextLong().toULong())
        hunt = app.model.read { db -> WordHunt.make(GameWords.pick(db, rng, 24, app.model.clock.today) { WordHunt.usable(it, size) }, rng, size) }
        found = emptySet(); hinted = emptySet(); seconds = 0; recorded = false; loaded = true
    }
    val h = hunt
    val done = h != null && found.size == h.words.size
    LaunchedEffect(h, done) { while (h != null && !done) { delay(1000); seconds++ } }
    LaunchedEffect(done) {
        if (done && h != null && !recorded) {
            recorded = true
            app.model.studied("word-hunt", Game.WORD_HUNT.source) { db -> h.record(found, hinted, seconds, app.model.clock, db) }
            Analytics.signal(Game.WORD_HUNT.signal, mapOf("seconds" to "$seconds", "hints" to "${hinted.size}"))
        }
    }

    PushedScreen("Kelime Avı", close = true) {
        if (!loaded) return@PushedScreen
        if (h == null) {
            EmptyText("Bu oyun için yeterli kelime yok. Widget'ta bir liste ya da kurs aç.")
            return@PushedScreen
        }
        if (done) {
            Kicker("KELİME AVI BİTTİ")
            Gap(8.dp)
            Text(time(seconds), style = KelimeType.english(64.sp), color = c.ink)
            Text("${h.words.size} kelime · ${hinted.size} ipucu", style = KelimeType.ui(15.sp), color = c.ink2)
            Gap(14.dp)
            for (w in h.words) {
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Text(w.card.word, style = KelimeType.english(19.sp), color = if (w.card.id in hinted) c.amberInk else c.greenInk, modifier = Modifier.weight(1f))
                    Text(w.card.meaning, style = KelimeType.ui(14.sp), color = c.ink2)
                }
            }
            Gap(16.dp)
            PrimaryButton("Sonucu paylaş") { sharing = true }
            Gap(8.dp)
            TintedButton("Bir tur daha") { round++ }
            Gap(8.dp)
            TintedButton("Bitti") { router.back() }
            if (sharing) ShareCardSheet(ShareCard.Content.Game("Kelime Avı", "${found.size}/${h.words.size}", "${time(seconds)} · ${hinted.size} ipucu")) { sharing = false }
            return@PushedScreen
        }
        Text("Türkçesine bakıp İngilizcesini bul: harflerin üstünde parmağını kaydır.", style = KelimeType.ui(14.sp), color = c.ink2)
        Gap(12.dp)
        Board(
            h, found, hinted,
            onFound = { word ->
                found = found + word.card.id
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            },
        )
        Gap(16.dp)
        Kicker("ANLAMLAR · ${found.size}/${h.words.size}")
        Gap(6.dp)
        for (w in h.words) {
            val isFound = w.card.id in found
            Row(Modifier.fillMaxWidth().heightIn(min = 42.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${w.card.meaning} (${w.answer.length})", style = KelimeType.ui(15.sp), color = if (isFound) c.ink2 else c.ink, modifier = Modifier.weight(1f))
                when {
                    isFound -> Text(w.card.word, style = KelimeType.english(17.sp), color = if (w.card.id in hinted) c.amberInk else c.greenInk)
                    w.card.id in hinted -> Text("${w.answer.first()}…", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.amberInk)
                    else -> Text("İlk harfi göster", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.accent, modifier = Modifier.clickable {
                        hinted = hinted + w.card.id
                        scope.launch { app.model.write("word-hunt-hint") { db -> LearningStore.record(LearningEvent.HintUsed, w.card.id, ReviewSource.WORD_HUNT, app.model.clock, db) } }
                    }.padding(8.dp))
                }
            }
        }
    }
}

/**
 * The Kelime Avı board (docs/SYNC.md): the letters on one white card (corner 20, hairline, 8 dp
 * inset). Found words get a round-capped green band under their letters (32 % opacity, 80 % of a
 * cell thick) and dark green bold letters; the drag draws the same band in blue (35 %), a miss
 * flashes it amber; a hint is an amber circle under the first letter. Bands fade in over 0.25 s.
 */
@Composable
private fun Board(hunt: WordHunt, found: Set<String>, hinted: Set<String>, onFound: (WordHunt.Placed) -> Unit) {
    val c = Palette.current
    var start by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var end by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var miss by remember { mutableStateOf<List<Pair<Int, Int>>?>(null) }
    val appear = remember(hunt) { mutableStateMapOf<String, Animatable<Float, AnimationVector1D>>() }
    LaunchedEffect(found) {
        for (id in found) if (id !in appear) {
            val anim = Animatable(0f)
            appear[id] = anim
            launch { anim.animateTo(1f, tween(250)) }
        }
    }
    LaunchedEffect(miss) {
        if (miss != null) { delay(350); miss = null }
    }
    val selection = line(start, end)
    val foundCells = hunt.words.filter { it.card.id in found }.flatMap { it.cells }.toSet()
    val hintCells = hunt.words.filter { it.card.id in hinted && it.card.id !in found }.map { it.firstCell }.toSet()
    Box(
        Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(20.dp)).background(c.surface)
            .border(1.dp, c.line, RoundedCornerShape(20.dp)).padding(8.dp),
    ) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val cellPx = constraints.maxWidth / hunt.size.toFloat()
            fun cellAt(x: Float, y: Float) = (y / cellPx).toInt().coerceIn(0, hunt.size - 1) to (x / cellPx).toInt().coerceIn(0, hunt.size - 1)
            fun center(p: Pair<Int, Int>) = Offset((p.second + 0.5f) * cellPx, (p.first + 0.5f) * cellPx)
            Canvas(Modifier.fillMaxSize()) {
                val width = cellPx * 0.8f
                fun band(cells: List<Pair<Int, Int>>, color: androidx.compose.ui.graphics.Color) {
                    if (cells.isEmpty()) return
                    drawLine(color, center(cells.first()), center(cells.last()), strokeWidth = width, cap = StrokeCap.Round)
                }
                for (w in hunt.words) if (w.card.id in found) band(w.cells, c.green.copy(alpha = 0.32f * (appear[w.card.id]?.value ?: 1f)))
                for (p in hintCells) drawCircle(c.amber.copy(alpha = 0.45f), radius = width / 2, center = center(p))
                miss?.let { band(it, c.amber.copy(alpha = 0.35f)) }
                if (selection.size > 0) band(selection, c.accent.copy(alpha = 0.35f))
            }
            Column(
                Modifier.fillMaxSize().pointerInput(hunt, found) {
                    detectDragGestures(
                        onDragStart = { o -> start = cellAt(o.x, o.y); end = start },
                        onDrag = { change, _ -> end = cellAt(change.position.x, change.position.y) },
                        onDragEnd = {
                            val cells = line(start, end)
                            val word = hunt.spelled(cells, skip = found)
                            if (word != null) onFound(word) else if (cells.size > 1) miss = cells
                            start = null; end = null
                        },
                        onDragCancel = { start = null; end = null },
                    )
                },
            ) {
                for (r in 0 until hunt.size) {
                    Row(Modifier.weight(1f)) {
                        for (col in 0 until hunt.size) {
                            val inFound = (r to col) in foundCells
                            Box(Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                                Text(
                                    hunt.letter(r, col).toString(),
                                    style = KelimeType.ui(if (hunt.size >= 10) 17.sp else 19.sp, if (inFound) FontWeight.Bold else FontWeight.Medium),
                                    color = if (inFound) c.greenInk else c.ink,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Cells on the straight line (row, column or 45°) from [a] to [b] in order; just [a] otherwise. */
private fun line(a: Pair<Int, Int>?, b: Pair<Int, Int>?): List<Pair<Int, Int>> {
    if (a == null || b == null) return emptyList()
    val dr = b.first - a.first
    val dc = b.second - a.second
    if (dr != 0 && dc != 0 && abs(dr) != abs(dc)) return listOf(a)
    val steps = maxOf(abs(dr), abs(dc))
    return (0..steps).map { (a.first + Integer.signum(dr) * it) to (a.second + Integer.signum(dc) * it) }
}

/**
 * Eşleştir (docs/V1_1_PLAN.md §2b): 60 seconds, five words left and five meanings right; a correct
 * pair leaves and a new one comes; a wrong pair shakes.
 */
@Composable
fun MatchScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val haptics = LocalHapticFeedback.current
    var game by remember { mutableStateOf<MatchGame?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var round by remember { mutableIntStateOf(0) }
    var version by remember { mutableIntStateOf(0) }
    var picked by remember { mutableStateOf<Int?>(null) }
    var miss by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    /** A right pair shown green for 0.42 s before it leaves the board. */
    var correct by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    val scope = rememberCoroutineScope()
    var left by remember { mutableIntStateOf(MatchGame.SECONDS) }
    var finished by remember { mutableStateOf(false) }
    var best by remember { mutableIntStateOf(0) }
    var newBest by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }
    var started by remember { mutableStateOf(false) }
    val shake = remember { Animatable(0f) }

    LaunchedEffect(round) {
        val rng = SeededGenerator(Random.nextLong().toULong())
        val pool = app.model.read { db -> GameWords.pick(db, rng, MatchGame.POOL, app.model.clock.today) }
        best = app.model.read { db -> GameResults.best(Game.MATCH, db) }
        game = if (pool.size >= 3) MatchGame(pool, rng) else null
        picked = null; miss = null; correct = null; left = MatchGame.SECONDS; finished = false; newBest = false; loaded = true
    }
    val g = game

    /** Plays the green pair now: after its 0.42 s, on the next tap, or when time runs out. */
    fun commitCorrect() {
        val pair = correct ?: return
        correct = null
        g?.pair(pair.first, pair.second)
        version++
    }
    @Suppress("UNUSED_VARIABLE") val v = version
    LaunchedEffect(g, finished, started) {
        if (!started) return@LaunchedEffect
        while (g != null && !finished && left > 0 && !g.isEmpty) { delay(1000); left-- }
        commitCorrect() // a pair still showing green counts
        if (g != null && !finished) {
            finished = true
            newBest = g.score > best
            app.model.studied("match", Game.MATCH.source) { db -> g.record(MatchGame.SECONDS - left, app.model.clock, db) }
            Analytics.signal(Game.MATCH.signal, mapOf("score" to "${g.score}"))
        }
    }
    // A wrong pair: both cards shake twice, 7 dp, in 0.4 s, and stay amber for 0.65 s.
    LaunchedEffect(miss) {
        if (miss != null) {
            launch { for (x in listOf(7f, -7f, 7f, -7f, 0f)) shake.animateTo(x, tween(80)) }
            delay(650)
            miss = null
        }
    }

    PushedScreen("Eşleştir", close = true) {
        if (!loaded) return@PushedScreen
        if (g == null) {
            EmptyText("Bu oyun için yeterli kelime yok. Widget'ta bir liste ya da kurs aç.")
            return@PushedScreen
        }
        if (!started) {
            Kicker("EŞLEŞTİR · 60 SANİYE")
            Gap(10.dp)
            Text(
                "İngilizce kelimeyi Türkçe anlamıyla eşleştir. Doğru çift gider; üç çift gidince yenileri gelir.",
                style = KelimeType.ui(17.sp), color = c.ink,
            )
            Gap(10.dp)
            if (best > 0) Text("En iyi skorun: $best", style = KelimeType.ui(14.sp), color = c.ink2)
            Gap(20.dp)
            PrimaryButton("Başla") { started = true }
            return@PushedScreen
        }
        if (finished) {
            Kicker("SÜRE BİTTİ")
            Gap(8.dp)
            Text("${g.score}", style = KelimeType.english(96.sp), color = c.ink)
            Text(if (newBest) "Yeni en iyi skor!" else "doğru eşleşme · en iyi ${maxOf(best, g.score)}", style = KelimeType.ui(16.sp, FontWeight.Medium), color = if (newBest) c.greenInk else c.ink2)
            if (g.missedIDs.isNotEmpty()) {
                Gap(8.dp)
                Text("Karıştırdığın ${g.missedIDs.size} kelime widget'ında daha sık gelecek.", style = KelimeType.ui(14.sp), color = c.amberInk)
            }
            Gap(18.dp)
            PrimaryButton("Sonucu paylaş") { sharing = true }
            Gap(8.dp)
            TintedButton("Bir tur daha") { round++; started = true }
            Gap(8.dp)
            TintedButton("Bitti") { router.back() }
            if (sharing) ShareCardSheet(ShareCard.Content.Game("Eşleştir", "${g.score}", "60 saniyede ${g.score} doğru eşleşme")) { sharing = false }
            return@PushedScreen
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Bir kelimeye, sonra Türkçesine dokun.", style = KelimeType.ui(14.sp), color = c.ink2, modifier = Modifier.weight(1f))
            Text("0:%02d".format(left), style = KelimeType.ui(22.sp, FontWeight.SemiBold), color = if (left <= 10) c.amberInk else c.ink)
        }
        Text("${g.score} doğru", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.greenInk)
        Gap(14.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                g.left.forEachIndexed { i, card ->
                    val shaking = miss?.first == i
                    val green = correct?.first == i
                    MatchSlot(card, "-en", card?.word, english = true, selected = picked == i, wrong = shaking, right = green,
                        modifier = if (shaking) Modifier.offset { IntOffset(shake.value.dp.roundToPx(), 0) } else Modifier) {
                        if (green) return@MatchSlot // green cards do nothing
                        commitCorrect()
                        if (g.left.getOrNull(i) != null) picked = i
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                g.right.forEachIndexed { j, card ->
                    val shaking = miss?.second == j
                    val green = correct?.second == j
                    MatchSlot(card, "-tr", card?.primaryMeaning, english = false, selected = false, wrong = shaking, right = green,
                        modifier = if (shaking) Modifier.offset { IntOffset(shake.value.dp.roundToPx(), 0) } else Modifier) {
                        if (green) return@MatchSlot
                        commitCorrect()
                        val i = picked ?: return@MatchSlot
                        picked = null
                        if (g.right.getOrNull(j) == null || g.left.getOrNull(i) == null) return@MatchSlot
                        if (g.isMatch(i, j)) {
                            // Right: both cards green with ✓ for 0.42 s, then they leave.
                            val pair = i to j
                            correct = pair
                            haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                            scope.launch {
                                delay(420)
                                if (correct == pair) commitCorrect()
                            }
                        } else {
                            g.pair(i, j) // counts the miss; the board stays
                            miss = i to j
                            haptics.performHapticFeedback(HapticFeedbackType.Reject)
                        }
                        version++
                    }
                }
            }
        }
    }
}

/**
 * One place on the board, a fixed 68 dp high. A matched card fades out in 0.3 s (ease-out) and
 * the place stays empty; a dealt card waits 0.25 s and fades in over 0.45 s (ease-in). The key is
 * the tile id (card id + "-en" / "-tr").
 */
@Composable
private fun MatchSlot(card: com.enesseval.kilitkelime.core.model.Card?, side: String, text: String?, english: Boolean, selected: Boolean, wrong: Boolean, right: Boolean, modifier: Modifier, onClick: () -> Unit) {
    AnimatedContent(
        targetState = card,
        contentKey = { it?.id?.plus(side) },
        transitionSpec = {
            fadeIn(tween(450, delayMillis = 250, easing = EaseIn)) togetherWith fadeOut(tween(300, easing = EaseOut))
        },
        label = "match-slot",
        modifier = Modifier.fillMaxWidth().height(68.dp),
    ) { shown ->
        if (shown == null) {
            Box(Modifier.fillMaxWidth().height(68.dp))
        } else {
            MatchTile(text, english, selected, wrong, right, modifier, onClick)
        }
    }
}

private class Look(val bg: androidx.compose.ui.graphics.Color, val border: androidx.compose.ui.graphics.Color, val width: androidx.compose.ui.unit.Dp, val ink: androidx.compose.ui.graphics.Color)

/**
 * A card. Right: green ground, 2 dp green border, dark green text with ✓, 5 % larger (spring).
 * Wrong: amber ground, 2 dp amber border, dark amber text with ✕. Never red.
 */
@Composable
private fun MatchTile(text: String?, english: Boolean, selected: Boolean, wrong: Boolean, right: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Palette.current
    val scale by animateFloatAsState(if (right) 1.05f else 1f, spring(dampingRatio = 0.55f), label = "match-scale")
    val look = when {
        text == null -> Look(c.background, c.line, 1.dp, c.ink2)
        right -> Look(c.greenBackground, c.green, 2.dp, c.greenInk)
        wrong -> Look(c.amberBackground, c.amber, 2.dp, c.amberInk)
        selected -> Look(c.accentSoft, c.accent, 1.dp, c.ink)
        else -> Look(c.surface, c.line, 1.dp, c.ink)
    }
    val mark = when {
        right -> "✓ "
        wrong -> "✕ "
        else -> ""
    }
    Box(
        modifier.fillMaxWidth().height(68.dp).scale(scale).clip(RoundedCornerShape(14.dp)).background(look.bg)
            .border(look.width, look.border, RoundedCornerShape(14.dp))
            .clickable(enabled = text != null, onClick = onClick).padding(horizontal = 10.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            mark + (text ?: ""), style = if (english) KelimeType.english(18.sp) else KelimeType.ui(14.sp, FontWeight.Medium),
            color = look.ink, maxLines = 2, textAlign = TextAlign.Center,
        )
    }
}
