package com.enesseval.kilitkelime.ui.play

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.crossword.PuzzleStore
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.ProBadge
import com.enesseval.kilitkelime.ui.components.ProCorner
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.ScreenTitle
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.TurkishDate
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.today.PuzzleThumbnail
import com.enesseval.kilitkelime.ui.today.SAMPLE_GRID
import com.enesseval.kilitkelime.ui.today.dailyPuzzleInfo

/** Oyna: Quick Review, today's crossword, the 1.1 games, and the Pro puzzles. */
@Composable
fun PlayScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val puzzle by loadData { db -> dailyPuzzleInfo(db, app.model.clock) }

    Column(
        Modifier.fillMaxSize().background(c.background).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp).padding(top = 6.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ScreenTitle("Oyna")
        SurfaceCard(padding = 20.dp, onClick = { router.startQuickReview() }) {
            Text("Hızlı Tekrar", style = KelimeType.english(30.sp), color = c.ink)
            Text("10 kelime · yaklaşık 2 dakika", style = KelimeType.ui(14.sp), color = c.ink2)
            Gap(12.dp)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Text(
                    "Başla", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.onAccent,
                    modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(c.accent).padding(horizontal = 18.dp, vertical = 12.dp),
                )
            }
        }
        SurfaceCard(padding = 0.dp) {
            Row(
                Modifier.fillMaxWidth().clickable { router.openPuzzle() }.padding(20.dp),
                horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                PuzzleThumbnail(8f, 2f, puzzle?.thumbnail ?: SAMPLE_GRID)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Günün Bulmacası", style = KelimeType.english(30.sp), color = c.ink)
                    Text(
                        puzzle?.let { if (it.completed) "Tamamlandı · yarın yenisi" else "${it.solved}/${it.total} kelime · ipuçları Türkçe" }
                            ?: "Şu anki bölümünden · ipuçları Türkçe",
                        style = KelimeType.ui(14.sp), color = c.ink2,
                    )
                }
            }
            Divider()
            SettingsRow("Arşiv", onClick = { if (pro) router.openArchive() else router.showPaywall(PaywallTrigger.ARCHIVE) }) {
                if (pro) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2) else ProBadge()
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GameCard("Kelime Avı", "Harflerin arasında gizli kelimeler", Modifier.weight(1f)) { router.openWordHunt() }
            GameCard("Eşleştir", "Kelimeyi anlamıyla eşle", Modifier.weight(1f)) { router.openMatch() }
        }
        ProCorner(!pro) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).border(1.dp, c.line, RoundedCornerShape(22.dp))
                    .clickable { if (pro) router.openPersonalPuzzle() else router.showPaywall(PaywallTrigger.PERSONAL_PUZZLE) }
                    .padding(horizontal = 20.dp, vertical = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Sana Özel Bulmaca", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink)
                    Text("Zorlandığın ve öğrendiğin kelimelerden", style = KelimeType.ui(13.sp), color = c.ink2)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2)
            }
        }
    }
}

@Composable
private fun GameCard(title: String, detail: String, modifier: Modifier, onClick: () -> Unit) {
    val c = Palette.current
    Column(
        modifier.heightIn(min = 120.dp).clip(RoundedCornerShape(22.dp)).background(c.surface).border(1.dp, c.line, RoundedCornerShape(22.dp))
            .clickable(onClick = onClick).padding(18.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(title, style = KelimeType.english(24.sp), color = c.ink)
        Text(detail, style = KelimeType.ui(13.sp), color = c.ink2)
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
        Box(Modifier.padding(top = 8.dp)) {}
    }
}
