package com.enesseval.kilitkelime.ui.paywall

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.model.FreeTrial
import com.enesseval.kilitkelime.ui.components.rememberReduceMotion
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette

private val staysFree = listOf("Kilit ekranı widget'ı", "Günün Bulmacası", "Sınırsız oyunlar", "Arşivden haftada 2 bulmaca", "İlk listen")
private val proOnly = listOf("Bulmaca arşivi sınırsız", "Sana Özel Bulmaca", "Sınav planı ve geri sayım", "Sınırsız liste")

/**
 * The page after the free trial (docs/SYNC.md, 1.2 cihaz testi A): a big accent icon, number boxes
 * (zero counts left out, the first two always there), what stays free and what Pro opens. The content
 * scrolls; "Pro'ya geç" and "Ücretsiz devam et" stay at the bottom.
 */
@Composable
fun TrialEndedPage(summary: FreeTrial.Summary, onPro: () -> Unit, onContinue: () -> Unit) {
    val c = Palette.current
    val reduce = rememberReduceMotion()
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val white = Color.White

    Box(Modifier.fillMaxSize().background(Color(0xFF080D24))) {
        NightSky()
        Column(Modifier.fillMaxSize()) {
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 20.dp).padding(top = 36.dp, bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Box(Modifier.size(88.dp).clip(CircleShape).background(c.accent.copy(alpha = 0.22f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Star, null, tint = c.accent, modifier = Modifier.size(48.dp))
                }
                Text("DENEME BİTTİ", style = KelimeType.ui(12.sp, FontWeight.Bold).copy(letterSpacing = 1.4.sp), color = c.accent)
                Text("3 günde şunları denedin", style = KelimeType.english(30.sp), color = white, textAlign = TextAlign.Center)

                // Two columns of number boxes, appearing 0.05 s apart.
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    summary.tiles().chunked(2).forEachIndexed { row, pair ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            pair.forEachIndexed { column, tile ->
                                val shown by animateFloatAsState(
                                    if (appeared || reduce) 1f else 0f,
                                    if (reduce) tween(0) else tween(300, delayMillis = 50 * (row * 2 + column)), label = "summaryTile",
                                )
                                Column(
                                    Modifier.weight(1f).alpha(shown).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.08f)).padding(14.dp),
                                    verticalArrangement = Arrangement.spacedBy(2.dp),
                                ) {
                                    Text(tile.value, style = KelimeType.english(32.sp), color = white)
                                    Text(tile.label, style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = white.copy(alpha = 0.7f))
                                }
                            }
                            if (pair.size == 1) Box(Modifier.weight(1f))
                        }
                    }
                }

                SummaryList("Ücretsiz devam eden", staysFree, free = true)
                SummaryList("Pro ile açılan", proOnly, free = false)
                Text("Verilerin yerinde, hiçbir şey silinmedi.", style = KelimeType.ui(12.sp), color = white.copy(alpha = 0.5f), textAlign = TextAlign.Center)
            }
            Column(
                Modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f), Color.Black)))
                    .navigationBarsPadding().padding(horizontal = 20.dp).padding(top = 24.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(
                    Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).background(c.accent).clickable(onClick = onPro),
                    contentAlignment = Alignment.Center,
                ) { Text("Pro'ya geç", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.onAccent) }
                Box(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(onClick = onContinue), contentAlignment = Alignment.Center) {
                    Text("Ücretsiz devam et", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = white)
                }
            }
        }
    }
}

@Composable
private fun SummaryList(title: String, items: List<String>, free: Boolean) {
    val c = Palette.current
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = KelimeType.ui(13.sp, FontWeight.Bold), color = c.accent)
        for (item in items) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(if (free) Icons.Filled.Check else Icons.Filled.Lock, null, tint = if (free) c.green else Color.White.copy(alpha = 0.55f), modifier = Modifier.size(18.dp))
                Text(item, style = KelimeType.ui(15.sp), color = Color.White.copy(alpha = if (free) 0.92f else 0.75f))
            }
        }
    }
}
