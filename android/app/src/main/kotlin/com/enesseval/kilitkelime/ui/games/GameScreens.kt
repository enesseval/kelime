package com.enesseval.kilitkelime.ui.games

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
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.games.GameResults
import com.enesseval.kilitkelime.core.games.GameWords
import com.enesseval.kilitkelime.core.games.MatchRound
import com.enesseval.kilitkelime.core.games.WordHunt
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs

/** Kelime Avı: find the hidden words; clues are their Turkish meanings. Drag across letters. */
@Composable
fun WordHuntScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var hunt by remember { mutableStateOf<WordHunt?>(null) }
    var round by remember { mutableIntStateOf(0) }
    var found by remember { mutableStateOf(setOf<String>()) }
    var shown by remember { mutableStateOf(setOf<String>()) }
    var start by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var end by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var seconds by remember { mutableIntStateOf(0) }
    var recorded by remember { mutableStateOf(false) }

    LaunchedEffect(round) {
        val rng = SystemRandom()
        hunt = app.model.read { db -> WordHunt.make(GameWords.pick(db, rng, 24) { it.isSingleWord && it.word.length in 3..WordHunt.SIZE }, rng) }
        found = emptySet(); shown = emptySet(); seconds = 0; recorded = false
        Analytics.send(Analytics.Event.wordHunt)
    }
    val h = hunt
    val done = h != null && (found + shown).size == h.words.size
    LaunchedEffect(h, done) { while (h != null && !done) { delay(1000); seconds++ } }
    LaunchedEffect(done) {
        if (done && h != null && !recorded) {
            recorded = true
            app.model.write("word-hunt") { db ->
                for (w in h.words) if (w.card.id in found) LearningStore.record(LearningEvent.Answered(true), w.card.id, ReviewSource.WORD_HUNT, app.model.clock, db)
                GameResults.record(Game.WORD_HUNT, found.size, h.words.size, seconds, app.model.clock, db)
            }
        }
    }

    PushedScreen("Kelime Avı", close = true) {
        if (h == null) {
            EmptyText("Bu oyun için yeterli kelime yok. Widget'ta bir liste ya da kurs aç.")
            return@PushedScreen
        }
        Text("Harflerin üstünde parmağını kaydır; kelimeler yatay, dikey ya da çapraz.", style = KelimeType.ui(14.sp), color = c.ink2)
        Gap(12.dp)
        val selection = remember(start, end) { line(start, end) }
        BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1f)) {
            val cellPx = constraints.maxWidth / h.size.toFloat()
            fun cellAt(x: Float, y: Float) = (y / cellPx).toInt().coerceIn(0, h.size - 1) to (x / cellPx).toInt().coerceIn(0, h.size - 1)
            Column(
                Modifier.fillMaxSize().pointerInput(h) {
                    detectDragGestures(
                        onDragStart = { o -> start = cellAt(o.x, o.y); end = start },
                        onDrag = { change, _ -> end = cellAt(change.position.x, change.position.y) },
                        onDragEnd = {
                            val s = start; val e = end
                            val word = if (s != null && e != null) h.match(s, e) else null
                            if (word != null && word.card.id !in found && word.card.id !in shown) found = found + word.card.id
                            start = null; end = null
                        },
                    )
                },
            ) {
                val foundCells = h.words.filter { it.card.id in found || it.card.id in shown }.flatMap { it.cells }.toSet()
                for (r in 0 until h.size) {
                    Row(Modifier.weight(1f)) {
                        for (col in 0 until h.size) {
                            val p = r to col
                            val bg = when {
                                p in selection -> c.accentSoft
                                p in foundCells -> c.greenBackground
                                else -> c.surface
                            }
                            Box(Modifier.weight(1f).fillMaxSize().padding(1.5.dp).clip(RoundedCornerShape(6.dp)).background(bg), contentAlignment = Alignment.Center) {
                                Text(h.letter(r, col).toString(), style = KelimeType.ui(20.sp, FontWeight.SemiBold), color = if (p in foundCells) c.greenInk else c.ink)
                            }
                        }
                    }
                }
            }
        }
        Gap(16.dp)
        Kicker("İPUÇLARI · ${found.size}/${h.words.size}")
        Gap(6.dp)
        for (w in h.words) {
            val isFound = w.card.id in found
            val isShown = w.card.id in shown
            Row(Modifier.fillMaxWidth().heightIn(min = 40.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "${w.card.meaning} (${w.answer.length})", style = KelimeType.ui(15.sp).copy(textDecoration = if (isFound) TextDecoration.LineThrough else null),
                    color = if (isFound) c.ink2 else c.ink, modifier = Modifier.weight(1f),
                )
                when {
                    isFound -> Text(w.card.word, style = KelimeType.english(17.sp), color = c.greenInk)
                    isShown -> Text(w.card.word, style = KelimeType.english(17.sp), color = c.amberInk)
                    else -> Text("Göster", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.accent, modifier = Modifier.clickable {
                        shown = shown + w.card.id
                        scope.launch { app.model.write("word-hunt-hint") { db -> LearningStore.record(LearningEvent.HintUsed, w.card.id, ReviewSource.WORD_HUNT, app.model.clock, db) } }
                    }.padding(8.dp))
                }
            }
        }
        if (done) {
            Gap(16.dp)
            Text("${found.size}/${h.words.size} kelime · %d:%02d".format(seconds / 60, seconds % 60), style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
            Gap(10.dp)
            PrimaryButton("Bir tur daha") { round++ }
            Gap(8.dp)
            TintedButton("Bitti") { router.back() }
        }
    }
}

/** Cells on the straight line (across, down or diagonal) from [a] to [b]; empty otherwise. */
private fun line(a: Pair<Int, Int>?, b: Pair<Int, Int>?): Set<Pair<Int, Int>> {
    if (a == null || b == null) return emptySet()
    val dr = b.first - a.first
    val dc = b.second - a.second
    if (dr != 0 && dc != 0 && abs(dr) != abs(dc)) return setOf(a)
    val steps = maxOf(abs(dr), abs(dc))
    val sr = Integer.signum(dr)
    val sc = Integer.signum(dc)
    return (0..steps).map { (a.first + sr * it) to (a.second + sc * it) }.toSet()
}

/** Eşleştir: tap an English word, then its Turkish meaning. */
@Composable
fun MatchScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    var round by remember { mutableStateOf<MatchRound?>(null) }
    var number by remember { mutableIntStateOf(0) }
    var version by remember { mutableIntStateOf(0) }
    var picked by remember { mutableStateOf<String?>(null) }
    var miss by remember { mutableStateOf<Pair<String, String>?>(null) }
    var seconds by remember { mutableIntStateOf(0) }
    var recorded by remember { mutableStateOf(false) }

    LaunchedEffect(number) {
        val rng = SystemRandom()
        val cards = app.model.read { db -> GameWords.pick(db, rng, MatchRound.SIZE) }
        round = if (cards.size >= 3) MatchRound(cards, rng) else null
        picked = null; miss = null; seconds = 0; recorded = false
        Analytics.send(Analytics.Event.match)
    }
    val r = round
    @Suppress("UNUSED_VARIABLE") val v = version
    val finished = r?.isFinished == true
    LaunchedEffect(r, finished) { while (r != null && !finished) { delay(1000); seconds++ } }
    LaunchedEffect(miss) { if (miss != null) { delay(700); miss = null } }
    LaunchedEffect(finished) {
        if (finished && r != null && !recorded) {
            recorded = true
            app.model.write("match") { db -> r.record(app.model.clock, db, seconds) }
        }
    }

    PushedScreen("Eşleştir", close = true) {
        if (r == null) {
            EmptyText("Bu oyun için yeterli kelime yok. Widget'ta bir liste ya da kurs aç.")
            return@PushedScreen
        }
        Text("Bir kelimeye, sonra Türkçesine dokun.", style = KelimeType.ui(14.sp), color = c.ink2)
        Gap(14.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                for (card in r.left) {
                    val done = card.id in r.matchedIDs
                    MatchTile(card.word, english = true, selected = picked == card.id, done = done, wrong = miss?.first == card.id) {
                        if (!done) picked = card.id
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                for (card in r.right) {
                    val done = card.id in r.matchedIDs
                    MatchTile(card.primaryMeaning, english = false, selected = false, done = done, wrong = miss?.second == card.id) {
                        val word = picked ?: return@MatchTile
                        if (done) return@MatchTile
                        if (!r.pair(word, card.id)) miss = word to card.id
                        picked = null
                        version++
                    }
                }
            }
        }
        if (finished) {
            Gap(18.dp)
            Text("${r.score}/${r.cards.size} ilk denemede · %d:%02d".format(seconds / 60, seconds % 60), style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
            Gap(10.dp)
            PrimaryButton("Bir tur daha") { number++ }
            Gap(8.dp)
            TintedButton("Bitti") { router.back() }
        }
    }
}

@Composable
private fun MatchTile(text: String, english: Boolean, selected: Boolean, done: Boolean, wrong: Boolean, onClick: () -> Unit) {
    val c = Palette.current
    val (bg, border, ink) = when {
        done -> Triple(c.greenBackground, c.green, c.greenInk)
        wrong -> Triple(c.amberBackground, c.amber, c.amberInk)
        selected -> Triple(c.accentSoft, c.accent, c.ink)
        else -> Triple(c.surface, c.line, c.ink)
    }
    Box(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).background(bg).border(1.dp, border, RoundedCornerShape(14.dp))
            .clickable(enabled = !done, onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = if (english) KelimeType.english(19.sp) else KelimeType.ui(15.sp, FontWeight.Medium), color = ink, maxLines = 2)
    }
}
