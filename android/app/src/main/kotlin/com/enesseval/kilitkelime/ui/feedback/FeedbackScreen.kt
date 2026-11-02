package com.enesseval.kilitkelime.ui.feedback

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch

/** "Kartı bildir" for a card, or "Öneri gönder" without one (port of `FeedbackForm.swift`). Works without an account. */
@Composable
fun FeedbackScreen(cardID: String?) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val card by loadData(cardID) { db -> cardID?.let { CardQueries.card(it, db) } }
    val reasons = if (cardID != null) {
        listOf("Anlam yanlış", "Örnek cümle hatalı", "Yazım hatası", "Türü ya da seviyesi yanlış", "Telaffuz", "Diğer")
    } else {
        listOf("Öneri", "Kelime ya da liste isteği", "Hata ya da sorun", "Diğer")
    }
    var reason by remember { mutableStateOf(reasons.first()) }
    var note by remember { mutableStateOf("") }
    var sent by remember { mutableStateOf(false) }
    var sending by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    PushedScreen(if (cardID != null) "Kartı bildir" else "Öneri gönder", close = true) {
        if (sent) {
            Text("Teşekkürler!", style = KelimeType.ui(22.sp, FontWeight.SemiBold), color = c.ink)
            Text(if (cardID != null) "Kartı inceleyip düzelteceğiz." else "Mesajın bize ulaştı.", style = KelimeType.ui(15.sp), color = c.ink2)
            Gap(16.dp)
            PrimaryButton("Kapat") { router.back() }
            return@PushedScreen
        }
        card?.let {
            Text(it.word, style = KelimeType.english(30.sp), color = c.ink)
            Text(it.meaning, style = KelimeType.ui(15.sp), color = c.ink2)
            Gap(12.dp)
        }
        SettingsSection(if (cardID != null) "NE YANLIŞ?" else "NE DÜŞÜNÜYORSUN?") {
            reasons.forEachIndexed { i, r ->
                if (i > 0) Divider()
                SettingsRow(r, onClick = { reason = r }) { if (r == reason) Text("✓", color = c.accent, style = KelimeType.ui(16.sp, FontWeight.Bold)) }
            }
        }
        Gap(14.dp)
        Kicker(if (cardID != null) "NOT (İSTEĞE BAĞLI)" else "NOT")
        Gap(6.dp)
        Box(Modifier.fillMaxWidth().heightIn(min = 120.dp).clip(RoundedCornerShape(12.dp)).background(c.surface2).padding(12.dp)) {
            if (note.isEmpty()) Text(if (cardID != null) "Doğrusu ne olmalı?" else "Ne düşünüyorsun?", style = KelimeType.ui(15.sp), color = c.ink2)
            BasicTextField(note, { note = it.take(1000) }, textStyle = KelimeType.ui(15.sp).copy(color = c.ink), cursorBrush = SolidColor(c.accent), modifier = Modifier.fillMaxWidth())
        }
        Gap(8.dp)
        Text("Adın ya da e-postan gönderilmez; yalnızca seçtiğin neden, notun ve uygulama sürümü.", style = KelimeType.ui(12.sp), color = c.ink2)
        error?.let { Gap(8.dp); Text(it, style = KelimeType.ui(13.sp), color = c.amberInk) }
        Gap(16.dp)
        PrimaryButton(if (sending) "Gönderiliyor…" else "Gönder", enabled = !sending && (cardID != null || note.isNotBlank())) {
            sending = true
            scope.launch {
                val ok = app.account.sendFeedback(if (cardID != null) "card" else "suggestion", card, reason, note)
                sending = false
                if (ok) sent = true else error = "Gönderilemedi. İnternet bağlantını kontrol edip tekrar dene."
            }
        }
    }
}
