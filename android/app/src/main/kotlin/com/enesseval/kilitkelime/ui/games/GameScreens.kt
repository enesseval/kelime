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
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
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

internal fun time(seconds: Int) = "%d:%02d".format(seconds / 60, seconds % 60)

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

    // iOS WordSearchView: close, title and the clock in the bar; "N / M kelime", the grid, the
    // clues in two columns and "İlk harfi göster" at the bottom.
    GameFrame("Kelime Avı", trailing = { Text(time(seconds), style = KelimeType.ui(13.sp), color = c.ink2) }) {
        if (!loaded) return@GameFrame
        if (h == null) {
            NotEnoughWords()
            return@GameFrame
        }
        if (done) {
            GameResult(
                title = "Kelime Avı tamam",
                headline = "${h.words.size} kelime",
                stats = listOf("süre" to time(seconds), "ipucu" to "${hinted.size}"),
                words = h.words.map { it.card },
                onAgain = { round++ },
                onClose = { router.back() },
                share = ShareCard.Content.Game("KELİME AVI", "${h.words.size} kelime", "${time(seconds)} · ${hinted.size} ipucu", h.words.map { it.card }),
            )
            return@GameFrame
        }
        Column(Modifier.fillMaxSize().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Text("${found.size} / ${h.words.size} kelime", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
            Box(Modifier.padding(horizontal = 12.dp)) {
                Board(h, found, hinted, onFound = { word ->
                    found = found + word.card.id
                    haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                }, onMiss = { haptics.performHapticFeedback(HapticFeedbackType.Reject) })
            }
            // Clues: two columns, meaning over "N harf" (or the word once found).
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (pair in h.words.chunked(2)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        for (w in pair) {
                            val isFound = w.card.id in found
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                                Text(
                                    w.card.primaryMeaning, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                    style = KelimeType.ui(14.sp, FontWeight.Medium).copy(textDecoration = if (isFound) TextDecoration.LineThrough else null),
                                    color = if (isFound) c.ink2 else c.ink,
                                )
                                if (isFound) Text(w.card.word, style = KelimeType.english(15.sp), color = c.greenInk)
                                else Text("${w.answer.length} harf", style = KelimeType.ui(12.sp), color = c.ink2)
                            }
                        }
                        if (pair.size == 1) Box(Modifier.weight(1f))
                    }
                }
            }
            Box(Modifier.weight(1f))
            Box(Modifier.padding(horizontal = 20.dp).padding(bottom = 12.dp)) {
                TintedButton("İlk harfi göster", height = 46.dp) {
                    val next = h.words.firstOrNull { it.card.id !in found && it.card.id !in hinted } ?: return@TintedButton
                    hinted = hinted + next.card.id
                    scope.launch { app.model.write("word-hunt-hint") { db -> LearningStore.record(LearningEvent.HintUsed, next.card.id, ReviewSource.WORD_HUNT, app.model.clock, db) } }
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
private fun Board(hunt: WordHunt, found: Set<String>, hinted: Set<String>, onFound: (WordHunt.Placed) -> Unit, onMiss: () -> Unit) {
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
                for (p in hintCells) drawCircle(c.amberBackground, radius = width / 2, center = center(p))
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
                            // iOS: fewer than three letters is no answer at all.
                            val word = if (cells.size >= 3) hunt.spelled(cells, skip = found) else null
                            if (word != null) onFound(word) else if (cells.size >= 3) { miss = cells; onMiss() }
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
    var pickedRight by remember { mutableStateOf<Int?>(null) }
    var miss by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    /** A right pair shown green for 0.42 s before it leaves the board. */
    var correct by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    /** Bumped for every right pair, so a pair's 0.42 s timer only ever plays its own pair. */
    var correctToken by remember { mutableIntStateOf(0) }
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
        picked = null; pickedRight = null; miss = null; correct = null; left = MatchGame.SECONDS; finished = false; newBest = false; loaded = true
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

    // iOS MatchView: close, title and the seconds left in the bar (amber from 10).
    GameFrame("Eşleştir", trailing = {
        Text("$left", style = KelimeType.ui(15.sp, FontWeight.Bold), color = if (left <= 10 && started) c.amberInk else c.ink2)
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
                    "İngilizce kelimeyi Türkçe anlamıyla eşleştir. Doğru çift gider; üç çift gidince yenileri gelir.",
                    style = KelimeType.ui(15.sp), color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp),
                )
                if (best > 0) Text("En iyi skorun: $best", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.greenInk)
                Box(Modifier.weight(1f))
                Box(Modifier.padding(horizontal = 20.dp).padding(bottom = 16.dp)) { PrimaryButton("Başla", height = 52.dp) { started = true } }
            }
            return@GameFrame
        }
        if (finished) {
            GameResult(
                title = if (g.score >= best && g.score > 0) "Yeni rekor!" else "Süre doldu",
                headline = "${g.score} eşleşme",
                stats = listOf("en iyi" to "${maxOf(best, g.score)}", "zorlandığın" to "${g.missedCards.size}"),
                words = g.missedCards,
                wordsTitle = "Widget'ında daha sık görünecek",
                onAgain = { round++; started = true },
                onClose = { router.back() },
                share = ShareCard.Content.Game("EŞLEŞTİR", "${g.score} eşleşme", "60 saniyede", g.firstTryCards),
            )
            return@GameFrame
        }
        /** iOS: either side can be tapped first; the second tap on the other side checks the pair. */
        fun check(i: Int, j: Int) {
            if (g.right.getOrNull(j) == null || g.left.getOrNull(i) == null) return
            if (g.isMatch(i, j)) {
                // Right: both cards green with ✓ for 0.42 s, then they leave.
                correct = i to j
                val token = ++correctToken
                haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                scope.launch {
                    delay(420)
                    if (correctToken == token) commitCorrect()
                }
            } else {
                g.pair(i, j) // counts the miss; the board stays
                miss = i to j
                haptics.performHapticFeedback(HapticFeedbackType.Reject)
            }
            version++
        }
        Column(Modifier.fillMaxSize().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("${g.score} eşleşme", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    g.left.forEachIndexed { i, card ->
                        val shaking = miss?.first == i
                        val green = correct?.first == i
                        MatchSlot(card, "-en", card?.word, english = true, selected = picked == i, wrong = shaking, right = green,
                            modifier = if (shaking) Modifier.offset { IntOffset(shake.value.dp.roundToPx(), 0) } else Modifier) {
                            if (green) return@MatchSlot // green cards do nothing
                            commitCorrect()
                            if (g.left.getOrNull(i) == null) return@MatchSlot
                            val j = pickedRight
                            if (j != null) { pickedRight = null; check(i, j) } else picked = if (picked == i) null else i
                        }
                    }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    g.right.forEachIndexed { j, card ->
                        val shaking = miss?.second == j
                        val green = correct?.second == j
                        MatchSlot(card, "-tr", card?.primaryMeaning, english = false, selected = pickedRight == j, wrong = shaking, right = green,
                            modifier = if (shaking) Modifier.offset { IntOffset(shake.value.dp.roundToPx(), 0) } else Modifier) {
                            if (green) return@MatchSlot
                            commitCorrect()
                            if (g.right.getOrNull(j) == null) return@MatchSlot
                            val i = picked
                            if (i != null) { picked = null; check(i, j) } else pickedRight = if (pickedRight == j) null else j
                        }
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

/** The games' bar (iOS): ✕ on the left, the title, a 44 dp trailing value (clock, seconds left). */
@Composable
internal fun GameFrame(title: String, trailing: @Composable () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val c = Palette.current
    val router = LocalRouter.current
    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp).heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).clip(CircleShape).clickable { router.back() }.semantics { contentDescription = "Kapat" }, contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Close, null, tint = c.ink2)
            }
            Text(title, style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.ink, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            Box(Modifier.width(44.dp), contentAlignment = Alignment.Center) { trailing() }
        }
        Column(Modifier.fillMaxSize(), content = content)
    }
}

@Composable
internal fun NotEnoughWords() {
    val c = Palette.current
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text("Yeterli kelime yok", style = KelimeType.ui(20.sp, FontWeight.SemiBold), color = c.ink)
        Gap(6.dp)
        Text("Widget'ında açık bir liste ya da kurs olmalı.", style = KelimeType.ui(15.sp), color = c.ink2, textAlign = TextAlign.Center)
    }
}

/** iOS GameResultView: title, headline, two stats, the round's words, share, again and close. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun GameResult(
    title: String, headline: String, stats: List<Pair<String, String>>, words: List<com.enesseval.kilitkelime.core.model.Card>,
    wordsTitle: String = "Bu turun kelimeleri", onAgain: () -> Unit, onClose: () -> Unit, share: ShareCard.Content,
    sentences: List<Pair<String, String>> = emptyList(),
) {
    val c = Palette.current
    var sharing by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 24.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        Text(title.uppercase(com.enesseval.kilitkelime.ui.components.TR), style = KelimeType.ui(13.sp, FontWeight.SemiBold).copy(letterSpacing = 1.sp), color = c.ink2)
        Text(headline, style = KelimeType.english(52.sp).copy(letterSpacing = (-1).sp), color = c.ink)
        Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            for ((label, value) in stats) {
                Column {
                    Text(value, style = KelimeType.ui(20.sp, FontWeight.Bold), color = c.ink)
                    Text(label, style = KelimeType.ui(14.sp), color = c.ink2)
                }
            }
        }
        if (words.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(wordsTitle, style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.ink)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (card in words) {
                        Text(
                            card.word, style = KelimeType.english(18.sp), color = c.ink,
                            modifier = Modifier.clip(CircleShape).background(c.surface2).padding(vertical = 6.dp, horizontal = 12.dp),
                        )
                    }
                }
            }
        }
        if (sentences.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Cümleler", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.ink)
                for ((en, tr) in sentences) {
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(en, style = KelimeType.english(18.sp), color = c.ink)
                        Text(tr, style = KelimeType.ui(13.sp), color = c.ink2)
                    }
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            PrimaryButton("Sonucu paylaş", height = 52.dp) { sharing = true }
            Row(Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Bir tur daha", style = KelimeType.ui(15.sp), color = c.ink2, modifier = Modifier.clickable(onClick = onAgain).padding(vertical = 10.dp))
                Box(Modifier.weight(1f))
                Text("Kapat", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.ink2, modifier = Modifier.clickable(onClick = onClose).padding(vertical = 10.dp))
            }
        }
    }
    if (sharing) ShareCardSheet(share) { sharing = false }
}
