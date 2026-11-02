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
                d?.puzzle?.let { if (it.completed) "Tamamlandı · yarın yenisi" else "${it.solved}/${it.total} kelime çözüldü" } ?: "0/5 kelime çözüldü",
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
        Text(title, style = KelimeType.english(23.sp), color = c.ink, maxLines = 2)
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
                drawRoundRect(if (solved) c.green else c.accent, Offset(col * s + 0.4f, row * s + 0.4f), Size(s - 0.8f, s - 0.8f), CornerRadius(s * 0.2f))
            }
        }
    }
}

@Composable
private fun ProRow(title: String, detail: String, pro: Boolean, onClick: () -> Unit) {
    val c = Palette.current
    SettingsRow(title, detail, onClick = onClick) {
        if (pro) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2) else ProBadge()
    }
}

/** Pro: earlier daily puzzles that were finished, to play again. */
@Composable
fun PuzzleArchiveScreen() {
    val router = LocalRouter.current
    val days by loadData { db -> PuzzleStore.completedDays(Preferences.load(db).level, db) }
    PushedScreen("Arşiv") {
        val list = days ?: return@PushedScreen
        if (list.isEmpty()) {
            EmptyText("Bitirdiğin bulmacalar burada görünür.")
            return@PushedScreen
        }
        SettingsSection("BİTİRDİKLERİN") {
            list.forEachIndexed { i, day ->
                if (i > 0) Divider()
                SettingsRow(TurkishDate.header(day), onClick = { router.openPuzzle(day.toString()) })
            }
        }
    }
}
