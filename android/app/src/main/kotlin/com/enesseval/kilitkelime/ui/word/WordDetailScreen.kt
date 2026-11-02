package com.enesseval.kilitkelime.ui.word

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Feedback
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.LearningEvent
import com.enesseval.kilitkelime.core.learning.LearningStore
import com.enesseval.kilitkelime.core.model.ReviewSource
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.queries.WordItem
import com.enesseval.kilitkelime.core.queries.WordQueries
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.EmptyText
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.LevelChip
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SegmentedPicker
import com.enesseval.kilitkelime.ui.components.StateChip
import com.enesseval.kilitkelime.ui.components.TR
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WordDetailScreen(cardID: String) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val item by loadData(cardID) { db -> WordQueries.item(cardID, db) }
    val rate by loadData { db -> Settings.string(db, SettingKey.SPEECH_RATE)?.toFloatOrNull() ?: 0.9f }
    val speaker = remember { Speaker(context) }
    DisposableEffect(Unit) { onDispose { speaker.shutdown() } }
    var sharing by remember { mutableStateOf(false) }

    fun record(event: LearningEvent, message: String?) = scope.launch {
        app.model.write("word-detail") { db -> LearningStore.record(event, cardID, ReviewSource.WORD_DETAIL, app.model.clock, db) }
        message?.let { router.toast = it }
    }

    PushedScreen(
        actions = {
            item?.let { current ->
                IconButton(onClick = {
                    scope.launch { app.model.write("favorite") { db -> LearningStore.setFavorite(!current.favorite, cardID, db) } }
                }) {
                    Icon(
                        if (current.favorite) Icons.Filled.Star else Icons.Outlined.StarOutline,
                        contentDescription = if (current.favorite) "Favorilerden çıkar" else "Favorilere ekle",
                        tint = if (current.favorite) c.amber else c.ink,
                    )
                }
                Text(
                    "Paylaş", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.accent,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable { sharing = true }.padding(horizontal = 12.dp, vertical = 10.dp),
                )
            }
        },
    ) {
        val current = item
        if (current == null) {
            EmptyText("Kelime bulunamadı")
            return@PushedScreen
        }
        Content(current, onSpeak = { speaker.rate = rate ?: 0.9f; speaker.speak(current.card.word) }, onReport = { router.openFeedback(cardID) })
        Gap(24.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            TintedButton("Biliyorum", Modifier.weight(1f), ink = c.greenInk, background = c.greenBackground, height = 56.dp) {
                record(LearningEvent.MarkedKnown, "Öğrenildi olarak işaretlendi")
            }
            TintedButton("Zorlanıyorum", Modifier.weight(1f), ink = c.amberInk, background = c.amberBackground, height = 56.dp) {
                record(LearningEvent.MarkedStruggling, "Bu kelimeyi widget'ında daha sık göreceksin")
            }
        }
    }

    if (sharing) {
        item?.let { current ->
            ModalBottomSheet(onDismissRequest = { sharing = false }, containerColor = c.background) {
                ShareSheet(current) { look ->
                    Analytics.send(Analytics.Event.shareCard)
                    ShareCard.share(context, current.card, look)
                    sharing = false
                }
            }
        }
    }
}

@Composable
private fun Content(item: WordItem, onSpeak: () -> Unit, onReport: () -> Unit) {
    val c = Palette.current
    val card = item.card
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            LevelChip(card.level, 12)
            Text(item.deckLabel, style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = c.ink2)
            StateChip(item.state)
        }
        Text(card.word, style = KelimeType.english(if (card.isPhrase) 38.sp else 56.sp).copy(letterSpacing = (-1).sp), color = c.ink)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.clip(CircleShape).background(c.accentSoft).clickable(onClick = onSpeak).padding(horizontal = 14.dp, vertical = 8.dp)
                    .semantics { contentDescription = "Telaffuzu dinle" },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.PlayArrow, null, tint = c.accent, modifier = Modifier.size(18.dp))
                Text("Dinle", style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.accent)
            }
            Text(card.pos.label, style = KelimeType.english(18.sp, italic = true), color = c.ink2)
        }
        Text(card.meaning, style = KelimeType.ui(22.sp, FontWeight.Medium), color = c.ink)
        if (card.exampleEN.isNotEmpty()) {
            Section("ÖRNEK") {
                Text(card.exampleEN, style = KelimeType.english(22.sp, italic = true), color = c.ink)
                Text(card.exampleTR, style = KelimeType.ui(15.sp), color = c.ink2)
            }
        }
        item.nextReview?.let { next ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Default.Refresh, null, tint = c.ink2, modifier = Modifier.size(16.dp))
                Text(nextReviewText(next), style = KelimeType.ui(13.sp), color = c.ink2)
            }
        }
        card.senses?.takeIf { it.isNotEmpty() }?.let { senses ->
            Section("DİĞER ANLAMLAR") {
                for (sense in senses) {
                    Text("${sense.pos.label}  ${sense.meaning}", style = KelimeType.ui(18.sp, FontWeight.Medium), color = c.ink)
                    Text(sense.exampleEN, style = KelimeType.english(18.sp, italic = true), color = c.ink)
                    Text(sense.exampleTR, style = KelimeType.ui(14.sp), color = c.ink2)
                    Gap(6.dp)
                }
            }
        }
        card.note?.let { note ->
            Section("DİKKAT") {
                Text(note, style = KelimeType.ui(15.sp), color = c.amberInk, modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(c.amberBackground).padding(12.dp))
            }
        }
        Row(
            Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onReport).padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(Icons.Outlined.Feedback, null, tint = c.ink2, modifier = Modifier.size(16.dp))
            Text("Bu kartta hata mı var? Bildir", style = KelimeType.ui(13.sp), color = c.ink2)
        }
    }
}

private fun nextReviewText(day: LocalDate): String {
    val today = LocalDate.now()
    return if (!day.isAfter(today)) "Tekrar zamanı geldi; widget'ta ve Hızlı Tekrar'da çıkacak"
    else "Sonraki tekrar: ${day.format(DateTimeFormatter.ofPattern("d MMMM", TR))}"
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Kicker(title)
        content()
    }
}

@Composable
private fun ShareSheet(item: WordItem, onShare: (ShareCard.Look) -> Unit) {
    val c = Palette.current
    val context = LocalContext.current
    var look by remember { mutableStateOf(ShareCard.Look.LIGHT) }
    val preview = remember(look) { ShareCard.render(context, item.card, look).asImageBitmap() }
    Column(Modifier.padding(horizontal = 20.dp).navigationBarsPadding().padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Kartı paylaş", style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink)
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Image(preview, contentDescription = null, modifier = Modifier.width(220.dp).clip(RoundedCornerShape(16.dp)).border(1.dp, c.line, RoundedCornerShape(16.dp)))
        }
        Text("Görünüm", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
        SegmentedPicker(ShareCard.Look.entries, look, { it.title }) { look = it }
        PrimaryButton("Paylaş") { onShare(look) }
    }
}
