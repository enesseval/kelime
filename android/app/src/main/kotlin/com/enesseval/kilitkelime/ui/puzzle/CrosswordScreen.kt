package com.enesseval.kilitkelime.ui.puzzle

import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.Offset
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.PauseCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.enesseval.kilitkelime.core.crossword.Crossword
import com.enesseval.kilitkelime.core.crossword.CrosswordEntry
import com.enesseval.kilitkelime.core.crossword.CrosswordGame
import com.enesseval.kilitkelime.core.crossword.DailyPuzzle
import com.enesseval.kilitkelime.core.crossword.DailyPuzzleSummary
import com.enesseval.kilitkelime.core.crossword.GridPoint
import com.enesseval.kilitkelime.core.crossword.PersonalPuzzle
import com.enesseval.kilitkelime.core.crossword.PuzzleStore
import com.enesseval.kilitkelime.core.dates.LocalDates
import com.enesseval.kilitkelime.core.dates.dayIndex
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.model.Card
import com.enesseval.kilitkelime.core.model.Json
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.PuzzleProgress
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.LetterKeyboard
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.TR
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate

private class Loaded(val key: String, val puzzle: Crossword, val saved: PuzzleStore.Saved, val cards: Map<String, Card>, val isDaily: Boolean, val day: LocalDate)

/** The daily (or personal) crossword with Turkish clues and the custom A–Z keyboard. */
@Composable
fun CrosswordScreen(dayText: String?, personal: Boolean) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var loaded by remember { mutableStateOf<Loaded?>(null) }
    var failed by remember { mutableStateOf(false) }
    var game by remember { mutableStateOf<CrosswordGame?>(null) }
    var version by remember { mutableIntStateOf(0) }
    var seconds by remember { mutableIntStateOf(0) }
    var completedAt by remember { mutableStateOf<Instant?>(null) }
    val nextGame by loadData(completedAt) { db -> com.enesseval.kilitkelime.core.games.FreeGames.next(db, app.model.clock) }
    var paused by remember { mutableStateOf(false) }
    var visible by remember { mutableStateOf(true) }
    var menu by remember { mutableStateOf(false) }
    var confirmRestart by remember { mutableStateOf(false) }
    var announced by remember { mutableIntStateOf(-1) }

    LaunchedEffect(Unit) {
        val clock = app.model.clock
        val result = app.model.read { db ->
            val prefs = Preferences.load(db)
            val day = dayText?.let(LocalDates::parse) ?: clock.today
            val (key, puzzle, isDaily) = if (!personal) {
                val (level, daily) = PuzzleLibrary.daily(context, prefs.level, day, db) ?: return@read null
                Triple(DailyPuzzle.key(level, day), daily, true)
            } else {
                val key = "personal-${clock.today}"
                val stored = PuzzleProgress.fetch(db, "$key-grid")?.let { runCatching { Json.decodeFromString(Crossword.serializer(), it.cells) }.getOrNull() }
                val puzzle = stored ?: PersonalPuzzle.make(db, clock, clock.today.dayIndex.toLong().toULong() * 7919uL + 17uL) ?: return@read null
                Triple(key, puzzle, false)
            }
            // Generated grids are kept once opened, so reopening shows the same grid.
            if (!isDaily || puzzle.id.startsWith("course-")) {
                if (PuzzleProgress.fetch(db, "$key-grid") == null) PuzzleProgress("$key-grid", Json.encodeToString(Crossword.serializer(), puzzle)).save(db)
            }
            val cards = CardQueries.cards(puzzle.entries.map { it.cardID }.toSet(), db).associateBy { it.id }
            Loaded(key, puzzle, PuzzleStore.load(key, puzzle, db), cards, isDaily, day)
        }
        if (result == null) { failed = true; return@LaunchedEffect }
        loaded = result
        game = result.saved.game
        seconds = result.saved.seconds
        completedAt = result.saved.completedAt
        announced = result.saved.game.solvedCount
    }

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_PAUSE) visible = false
            if (e == Lifecycle.Event.ON_RESUME) visible = true
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    suspend fun save(announce: Boolean) {
        val l = loaded ?: return
        val g = game ?: return
        val summary = DailyPuzzleSummary.of(app.model.clock.today, g)
        val body: (com.enesseval.kilitkelime.core.db.SqlDb) -> Unit = { db ->
            PuzzleStore.save(l.key, g, seconds, completedAt, db)
            if (l.isDaily && l.day == summary.day) summary.save(db)
        }
        if (announce) {
            announced = g.solvedCount
            // A solved word in today's daily puzzle counts today for the streak.
            app.model.studied("puzzle", com.enesseval.kilitkelime.core.games.StreakSource.PUZZLE) { db ->
                body(db)
                PuzzleStore.markStudiedIfSolved(g, l.isDaily, l.day, app.model.clock, db)
            }
        } else {
            app.model.read { db -> db.transaction { body(db) } }
        }
    }

    // The clock runs only on screen and unpaused; saves every 10 seconds.
    LaunchedEffect(loaded, paused, visible, completedAt) {
        while (loaded != null && !paused && visible && completedAt == null) {
            delay(1000)
            seconds++
            if (seconds % 10 == 0) save(false)
        }
    }
    DisposableEffect(Unit) { onDispose { app.model.scope.launch { save(true) } } }

    fun afterChange(hintEntry: CrosswordEntry? = null) {
        val g = game ?: return
        version++
        scope.launch {
            if (hintEntry != null) app.model.write("puzzle-hint") { db -> PuzzleStore.recordHint(hintEntry, app.model.clock, db) }
            if (g.isComplete && completedAt == null) {
                completedAt = app.model.clock.now
                save(true)
                app.model.write("puzzle-done") { db -> PuzzleStore.recordCompletion(g, app.model.clock, db) }
            } else {
                save(g.solvedCount != announced)
            }
        }
    }

    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { router.back() }) { Icon(Icons.Default.Close, "Kapat", tint = c.ink) }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (personal) "Sana Özel Bulmaca" else "Günün Bulmacası", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink)
                game?.let { g ->
                    @Suppress("UNUSED_VARIABLE") val v = version
                    Text("Süre ${time(seconds)} · ${g.solvedCount}/${g.puzzle.entries.size} kelime", style = KelimeType.ui(12.sp), color = c.ink2)
                }
            }
            IconButton(onClick = { paused = !paused }) {
                Icon(Icons.Outlined.PauseCircle, if (paused) "Devam et, süre ${time(seconds)}" else "Duraklat, süre ${time(seconds)}", tint = c.ink)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, "İpuçları", tint = c.ink) }
                DropdownMenu(menu, { menu = false }) {
                    val g = game
                    DropdownMenuItem(text = { Text("Harf aç") }, enabled = g != null && completedAt == null, onClick = { menu = false; g?.let { afterChange(it.revealLetter()) } })
                    DropdownMenuItem(text = { Text("Kelimeyi kontrol et") }, enabled = g != null && completedAt == null, onClick = {
                        menu = false
                        g?.let { val entry = it.activeEntry; if (it.checkWord()) afterChange(entry) else afterChange() }
                    })
                    DropdownMenuItem(text = { Text("Kelimeyi göster") }, enabled = g != null && completedAt == null, onClick = { menu = false; g?.let { afterChange(it.revealWord()) } })
                    DropdownMenuItem(text = { Text("Baştan başla") }, onClick = { menu = false; confirmRestart = true })
                }
            }
        }
        val l = loaded
        val g = game
        when {
            failed -> Box(Modifier.padding(20.dp)) { EmptyText("Bulmaca hazırlanamadı") }
            l == null || g == null -> {}
            completedAt != null -> Completion(
                g, l, seconds, onAgain = { confirmRestart = true }, onClose = { router.back() },
                next = if (l.isDaily) nextGame else null,
                onNext = { game ->
                    router.back()
                    when (game) {
                        com.enesseval.kilitkelime.core.games.Game.WORD_HUNT -> router.openWordHunt()
                        com.enesseval.kilitkelime.core.games.Game.MATCH -> router.openMatch()
                        com.enesseval.kilitkelime.core.games.Game.SENTENCE -> router.openSentence()
                        com.enesseval.kilitkelime.core.games.Game.GAP_FILL -> router.openGapFill()
                    }
                },
            )
            paused -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Duraklatıldı", style = KelimeType.ui(20.sp, FontWeight.SemiBold), color = c.ink)
                    TintedButton("Devam et", fullWidth = false) { paused = false }
                }
            }
            else -> {
                @Suppress("UNUSED_VARIABLE") val v = version
                Box(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), contentAlignment = Alignment.Center) {
                    Grid(g) { point -> g.select(point); version++ }
                }
                ClueBar(g, l.cards, onStep = { g.step(it); version++ })
                LetterKeyboard(keyHeight = 48.dp, onLetter = { g.type(it); afterChange() }, onDelete = { g.deleteBackward(); afterChange() })
            }
        }
    }

    if (confirmRestart) {
        AlertDialog(
            onDismissRequest = { confirmRestart = false },
            containerColor = c.surface,
            title = { Text("Bulmaca baştan başlasın mı?") },
            text = { Text("Yazdığın harfler ve süre silinir.") },
            confirmButton = {
                Text("Baştan başla", color = c.accent, style = KelimeType.ui(15.sp, FontWeight.SemiBold), modifier = Modifier.clickable {
                    confirmRestart = false
                    val current = loaded ?: return@clickable
                    scope.launch {
                        app.model.read { db -> db.execute("DELETE FROM puzzle_progress WHERE puzzle_key = ?", listOf(current.key)) }
                        game = CrosswordGame(current.puzzle)
                        seconds = 0
                        completedAt = null
                        version++
                    }
                }.padding(12.dp))
            },
            dismissButton = { Text("Vazgeç", color = c.ink2, modifier = Modifier.clickable { confirmRestart = false }.padding(12.dp)) },
        )
    }
}

private fun time(seconds: Int) = "%d:%02d".format(seconds / 60, seconds % 60)

@Composable
private fun Grid(game: CrosswordGame, onSelect: (GridPoint) -> Unit) {
    val c = Palette.current
    val puzzle = game.puzzle
    val solution = remember(puzzle) { puzzle.solution }
    val numbers = remember(puzzle) { puzzle.numbers }
    val active = game.activeEntry.cells.toSet()
    BoxWithConstraints {
        val cell = minOf(maxWidth / puzzle.width, maxHeight / puzzle.height, 44.dp)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            for (row in 0 until puzzle.height) {
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    for (col in 0 until puzzle.width) {
                        val point = GridPoint(row, col)
                        if (solution[point] == null) {
                            Box(Modifier.size(cell - 2.dp))
                            continue
                        }
                        val letter = game.typed[point]
                        val solved = puzzle.entriesAt(point).any(game::isSolved)
                        val bg = when {
                            point == game.cursor -> c.accent
                            point in active -> c.accentSoft
                            solved -> c.greenBackground
                            else -> c.surface
                        }
                        val ink = when {
                            point == game.cursor -> c.onAccent
                            point in game.wrong -> c.amberInk
                            point in game.revealed -> c.accent
                            else -> c.ink
                        }
                        Box(
                            Modifier.size(cell - 2.dp).clip(RoundedCornerShape(5.dp)).background(bg)
                                .border(1.dp, if (point in game.wrong) c.amber else c.line, RoundedCornerShape(5.dp))
                                .clickable { onSelect(point) }
                                .semantics { contentDescription = "satır ${row + 1}, sütun ${col + 1}, ${letter ?: "boş"}" },
                        ) {
                            numbers[point]?.let { Text("$it", style = KelimeType.ui(8.sp, FontWeight.SemiBold), color = if (point == game.cursor) c.onAccent else c.ink2, modifier = Modifier.padding(start = 2.dp)) }
                            Text(letter?.toString() ?: "", style = KelimeType.ui((cell.value * 0.5f).sp, FontWeight.SemiBold), color = ink, modifier = Modifier.align(Alignment.Center))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ClueBar(game: CrosswordGame, cards: Map<String, Card>, onStep: (Int) -> Unit) {
    val c = Palette.current
    val entry = game.activeEntry
    val meaning = cards[entry.cardID]?.meaning ?: ""
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).background(c.accentSoft).padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = { onStep(-1) }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Önceki ipucu", tint = c.ink) }
        Column(Modifier.weight(1f)) {
            Text("${entry.number} ${entry.direction.label.uppercase(TR)} · ${entry.length} HARF", style = KelimeType.ui(11.sp, FontWeight.SemiBold), color = c.ink2)
            Text(meaning, style = KelimeType.ui(16.sp, FontWeight.Medium), color = c.ink, maxLines = 2)
        }
        IconButton(onClick = { onStep(1) }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Sonraki ipucu", tint = c.ink) }
    }
}

/** iOS PuzzleCompletionView: title, "6 kelime, 4 dakika.", time and hints, helped words, the spoiler-free grid. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun Completion(
    game: CrosswordGame, loaded: Loaded, seconds: Int, onAgain: () -> Unit, onClose: () -> Unit,
    next: com.enesseval.kilitkelime.core.games.Game?, onNext: (com.enesseval.kilitkelime.core.games.Game) -> Unit,
) {
    val c = Palette.current
    val helped = game.puzzle.orderedEntries.filter { it.id in game.helped }.mapNotNull { loaded.cards[it.cardID] }
    val helpedCells = game.puzzle.entries.filter { it.id in game.helped }.flatMap { it.cells }.map { it.row to it.col }.toSet()
    var sharing by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 30.dp, bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        Text("BULMACA TAMAM", style = KelimeType.ui(13.sp, FontWeight.SemiBold).copy(letterSpacing = 1.sp), color = c.ink2)
        Text("${game.puzzle.entries.size} kelime,\n${maxOf(1, Math.round(seconds / 60.0).toInt())} dakika.", style = KelimeType.english(52.sp).copy(letterSpacing = (-1).sp), color = c.ink)
        Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            for ((value, label) in listOf(time(seconds) to "süre", "${game.hintsUsed}" to "ipucu")) {
                Column {
                    Text(value, style = KelimeType.ui(20.sp, FontWeight.Bold), color = c.ink)
                    Text(label, style = KelimeType.ui(14.sp), color = c.ink2)
                }
            }
        }
        if (helped.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Widget'ına eklenen kelimeler", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.ink)
                androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (card in helped) {
                        Text(card.word, style = KelimeType.english(18.sp), color = c.ink, modifier = Modifier.clip(CircleShape).background(c.amberBackground).padding(vertical = 6.dp, horizontal = 12.dp))
                    }
                }
            }
        }
        // ShareGrid: 14 dp cells, 3 dp gaps; green alone, amber with help.
        Canvas(Modifier.size(width = (game.puzzle.width * 17 - 3).dp, height = (game.puzzle.height * 17 - 3).dp)) {
            val cell = 14.dp.toPx()
            val step = 17.dp.toPx()
            for (entry in game.puzzle.entries) for (p in entry.cells) {
                drawRoundRect(
                    if ((p.row to p.col) in helpedCells) c.amber else c.green,
                    topLeft = Offset(p.col * step, p.row * step), size = Size(cell, cell), cornerRadius = CornerRadius(cell * 0.2f),
                )
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            PrimaryButton("Sonucu paylaş", height = 52.dp) { sharing = true }
            // The next free game (docs/V1_2_PLAN.md §3); Pro is not pushed here.
            if (next != null) com.enesseval.kilitkelime.ui.components.OutlineButton("Devam et: ${next.title}", Modifier.fillMaxWidth()) { onNext(next) }
            Row(Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Yeniden çöz", style = KelimeType.ui(15.sp), color = c.ink2, modifier = Modifier.clickable(onClick = onAgain).padding(vertical = 10.dp))
                Box(Modifier.weight(1f))
                Text("Kapat", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.ink2, modifier = Modifier.clickable(onClick = onClose).padding(vertical = 10.dp))
            }
            if (loaded.isDaily) Text("Yarın yeni bulmaca seni bekliyor.", style = KelimeType.ui(13.sp), color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        }
    }
    if (sharing) {
        val cells = HashMap<Pair<Int, Int>, Boolean?>()
        for (entry in game.puzzle.entries) for (cell in entry.cells) {
            val key = cell.row to cell.col
            cells[key] = key !in helpedCells
        }
        com.enesseval.kilitkelime.ui.share.ShareCardSheet(
            com.enesseval.kilitkelime.ui.word.ShareCard.Content.Puzzle(
                if (loaded.isDaily) "Günün Bulmacası" else "Sana Özel Bulmaca",
                game.puzzle.width, game.puzzle.height, cells, game.puzzle.entries.size, time(seconds), game.hintsUsed,
            ),
        ) { sharing = false }
    }
}
