package com.enesseval.kilitkelime.ui.play

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.automirrored.filled.CompareArrows
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.crossword.PuzzleStore
import com.enesseval.kilitkelime.core.db.int
import com.enesseval.kilitkelime.core.games.Game
import com.enesseval.kilitkelime.core.games.GameResults
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.ProBadge
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.ScreenTitle
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.TurkishDate
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.today.DailyPuzzleInfo
import com.enesseval.kilitkelime.ui.today.SAMPLE_GRID
import com.enesseval.kilitkelime.ui.today.dailyPuzzleInfo

private data class PlayData(val struggling: Int, val puzzle: DailyPuzzleInfo?, val matchBest: Int)

/**
 * Oyna (docs/SYNC.md 2026-11-02): the four games as equal cards in a 2 × 2 grid, and below them one
 * card with the two Pro rows. Bugün has no games any more.
 */
@Composable
fun PlayScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val data by loadData { db ->
        PlayData(
            db.int("SELECT COUNT(*) FROM card_state WHERE state = 'struggling'"),
            dailyPuzzleInfo(db, app.model.clock),
            GameResults.best(Game.MATCH, db),
        )
    }

    Column(
        Modifier.fillMaxSize().background(c.background).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp).padding(top = 6.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ScreenTitle("Oyna")
        val d = data
        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GameCard(
                "Hızlı Tekrar",
                if ((d?.struggling ?: 0) > 0) "${d!!.struggling} zorlandığın kelime seni bekliyor" else "10 kelime · 2 dakika",
                strong = (d?.struggling ?: 0) > 0,
                modifier = Modifier.weight(1f),
                icon = { IconBox(Icons.Filled.Bolt) },
            ) { router.startQuickReview() }
            GameCard(
                "Günün Bulmacası",
                d?.puzzle?.let { if (it.completed) "Tamamlandı · yarın yenisi" else "${it.solved}/${it.total} kelime çözüldü" } ?: "İpuçları Türkçe",
                modifier = Modifier.weight(1f),
                icon = { PuzzleIcon(d?.puzzle?.thumbnail ?: SAMPLE_GRID) },
            ) { router.openPuzzle() }
        }
        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GameCard("Kelime Avı", "Anlamından bul", modifier = Modifier.weight(1f), icon = { IconBox(Icons.Filled.Search) }) { router.openWordHunt() }
            GameCard(
                "Eşleştir",
                if ((d?.matchBest ?: 0) > 0) "60 saniye · en iyi ${d!!.matchBest}" else "60 saniye",
                modifier = Modifier.weight(1f),
                icon = { IconBox(Icons.AutoMirrored.Filled.CompareArrows) },
            ) { router.openMatch() }
        }
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(c.surface).border(1.dp, c.line, RoundedCornerShape(22.dp)),
        ) {
            ProRow("Bulmaca arşivi", "Geçmiş günlerin bulmacaları", pro) {
                if (pro) router.openArchive() else router.showPaywall(PaywallTrigger.ARCHIVE)
            }
            Divider()
            ProRow("Sana Özel Bulmaca", "Zorlandığın ve öğrendiğin kelimelerden", pro) {
                if (pro) router.openPersonalPuzzle() else router.showPaywall(PaywallTrigger.PERSONAL_PUZZLE)
            }
        }
    }
}

/** One game: a 44 dp blue box with the icon, the title (serif 23) and up to two lines; at least 150 dp high. */
@Composable
private fun GameCard(title: String, subtitle: String, modifier: Modifier, strong: Boolean = false, icon: @Composable () -> Unit, onClick: () -> Unit) {
    val c = Palette.current
    Column(
        modifier.fillMaxHeight().heightIn(min = 150.dp).clip(RoundedCornerShape(22.dp)).background(c.surface)
            .border(1.dp, c.line, RoundedCornerShape(22.dp)).clickable(role = Role.Button, onClick = onClick).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        icon()
        Box(Modifier.weight(1f))
        Text(title, style = KelimeType.english(23.sp), color = c.ink, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis)
        Text(
            subtitle, maxLines = 2, overflow = TextOverflow.Ellipsis,
            style = KelimeType.ui(13.sp, if (strong) FontWeight.SemiBold else FontWeight.Normal),
            color = if (strong) c.amberInk else c.ink2,
        )
    }
}

@Composable
private fun IconBox(icon: ImageVector) {
    val c = Palette.current
    Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(c.accentSoft), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = null, tint = c.accent)
    }
}

/** A small crossword grid in the blue box: unsolved cells blue, solved ones green. */
@Composable
private fun PuzzleIcon(cells: Map<Int, Boolean>) {
    val c = Palette.current
    Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(c.accentSoft), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(width = 26.dp, height = 32.dp)) {
            val s = size.width / 8f
            for ((index, solved) in cells) {
                val row = index / 8
                val col = index % 8
                if (row >= 10) continue
                drawRoundRect(if (solved) c.green else c.accent.copy(alpha = 0.55f), Offset(col * s + 0.4f, row * s + 0.4f), Size(s - 0.8f, s - 0.8f), CornerRadius(s * 0.2f))
            }
        }
    }
}

/** iOS proRow: title over a grey line, then a chevron (Pro) or the Pro badge. */
@Composable
private fun ProRow(title: String, detail: String, pro: Boolean, onClick: () -> Unit) {
    val c = Palette.current
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink)
            Text(detail, style = KelimeType.ui(13.sp), color = c.ink2)
        }
        if (pro) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2) else ProBadge()
    }
}

private data class ArchiveRow(val day: java.time.LocalDate, val level: com.enesseval.kilitkelime.core.model.CEFRLevel, val solved: Int, val total: Int, val completed: Boolean)

/** Pro (iOS PuzzleArchiveView): the last 30 days' daily puzzles with their progress. */
@Composable
fun PuzzleArchiveScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val context = androidx.compose.ui.platform.LocalContext.current
    val c = Palette.current
    val rows by loadData { db ->
        val prefs = Preferences.load(db)
        (1..30).mapNotNull { offset ->
            val day = app.model.clock.today.minusDays(offset.toLong())
            val (level, generated) = com.enesseval.kilitkelime.ui.puzzle.PuzzleLibrary.daily(context, prefs.level, day, db) ?: return@mapNotNull null
            val key = com.enesseval.kilitkelime.core.crossword.DailyPuzzle.key(level, day)
            // A grid opened before is kept under "<key>-grid"; use it so the counts match what was played.
            val puzzle = com.enesseval.kilitkelime.core.model.PuzzleProgress.fetch(db, "$key-grid")?.let {
                runCatching { kotlinx.serialization.json.Json.decodeFromString(com.enesseval.kilitkelime.core.crossword.Crossword.serializer(), it.cells) }.getOrNull()
            } ?: generated
            val saved = PuzzleStore.load(key, puzzle, db)
            ArchiveRow(day, level, saved.game.solvedCount, puzzle.entries.size, saved.completedAt != null)
        }
    }
    PushedScreen("Arşiv") {
        val list = rows ?: return@PushedScreen
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.surface)) {
            list.forEachIndexed { i, row ->
                if (i > 0) Divider()
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 50.dp).clickable { router.openPuzzle(row.day.toString()) }.padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(TurkishDate.header(row.day), style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink)
                        Text("${row.level.raw} · ${row.solved}/${row.total} kelime", style = KelimeType.ui(13.sp), color = c.ink2)
                    }
                    if (row.completed) Text("✓", style = KelimeType.ui(16.sp, FontWeight.Bold), color = c.greenInk)
                }
            }
        }
    }
}
