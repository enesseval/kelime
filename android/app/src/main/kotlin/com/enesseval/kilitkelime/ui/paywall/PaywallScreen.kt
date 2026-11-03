package com.enesseval.kilitkelime.ui.paywall

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.store.PurchaseManager
import com.enesseval.kilitkelime.ui.LocalActivity
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.ProCorner
import com.enesseval.kilitkelime.ui.profile.PRIVACY_URL
import com.enesseval.kilitkelime.ui.profile.TERMS_URL
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.revenuecat.purchases.Package
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

private enum class Plan(val title: String) { MONTHLY("Aylık"), ANNUAL("Yıllık"), LIFETIME("Ömür boyu") }

private data class Feature(val id: String, val title: String)

private val features = listOf(
    Feature("lists", "Sınırsız kendi listen"),
    Feature("share", "Listeni paylaş"),
    Feature("discover", "Keşfet'ten hazır listeler"),
    Feature("exam", "Sınav planı"),
    Feature("rotation", "Daha sık yeni kelime"),
    Feature("puzzle", "Sana özel bulmaca"),
)

private fun focus(trigger: PaywallTrigger) = when (trigger) {
    PaywallTrigger.LISTS -> "lists"
    PaywallTrigger.SHARE -> "share"
    PaywallTrigger.EXAM_PLAN -> "exam"
    PaywallTrigger.ROTATION -> "rotation"
    PaywallTrigger.PERSONAL_PUZZLE, PaywallTrigger.ARCHIVE -> "puzzle"
    PaywallTrigger.DISCOVER -> "discover"
    PaywallTrigger.BASE, PaywallTrigger.MOMENT -> null
}

private fun subtitle(trigger: PaywallTrigger) = when (trigger) {
    PaywallTrigger.LISTS -> "Ücretsizde bir listen var. Pro ile istediğin kadar liste oluştur."
    PaywallTrigger.SHARE -> "Listeni linkle gönder ya da Keşfet'te herkese aç."
    PaywallTrigger.ROTATION -> "Kilit ekranında gün boyu daha çok kelime."
    PaywallTrigger.PERSONAL_PUZZLE -> "Zorlandığın ve öğrendiğin kelimelerden karışık bir bulmaca."
    PaywallTrigger.ARCHIVE -> "Kaçırdığın günlerin bulmacalarını çöz."
    PaywallTrigger.EXAM_PLAN -> "Sınav gününe kadar her gün kaç kelime çalışman gerektiğini görelim."
    PaywallTrigger.DISCOVER -> "Diğer öğrencilerin hazırladığı listeleri ekle; widget'ında dönsün."
    PaywallTrigger.MOMENT -> "Birkaç gündür buradasın. Ücretsiz olan her şey öyle kalır; Pro daha fazlasını açar."
    PaywallTrigger.BASE -> "Kurs, sınav listeleri ve Hızlı Tekrar ücretsiz kalır; Pro yenilerini ekler."
}

private fun PurchaseManager.State.pkg(plan: Plan): Package? = when (plan) {
    Plan.MONTHLY -> monthly
    Plan.ANNUAL -> annual
    Plan.LIFETIME -> lifetime
}

private fun Package.price(): String = product.price.formatted

/** Play shows only offers the user is eligible for: a free phase means the trial applies. */
private fun Package.hasTrial(): Boolean = product.defaultOption?.freePhase != null

private fun Package.perMonth(): String? {
    val micros = product.price.amountMicros
    if (micros <= 0) return null
    val format = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("tr-TR"))
    runCatching { format.currency = Currency.getInstance(product.price.currencyCode) }
    return format.format(micros / 12.0 / 1_000_000.0)
}

/**
 * The paywall (port of the live iOS `WidgetPaywall`): headline for the trigger, a lock-screen
 * preview cycling words, the features with the trigger's first, the three plans, and under the
 * button what is billed and when (Google Play subscription disclosure).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PaywallScreen(trigger: PaywallTrigger) {
    val app = LocalApp.current
    val router = LocalRouter.current
    val activity = LocalActivity.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val state by app.purchases.state.collectAsState()
    val pro by app.model.isPro.collectAsState()
    var plan by remember { mutableStateOf(Plan.ANNUAL) }
    var working by remember { mutableStateOf(false) }
    var tick by remember { mutableIntStateOf(0) }
    val words = listOf("resilient" to "dayanıklı", "eager" to "istekli", "thrive" to "gelişmek", "subtle" to "ince, belli belirsiz", "vivid" to "canlı")

    LaunchedEffect(Unit) { app.purchases.loadProducts() }
    LaunchedEffect(pro) { if (pro) router.back() }
    LaunchedEffect(Unit) { while (true) { delay(1600); tick++ } }

    val selected = state.pkg(plan)
    val trial = state.annual?.hasTrial() == true
    fun note(p: Plan): String = when (p) {
        Plan.MONTHLY -> "Her ay yenilenir"
        Plan.ANNUAL -> listOfNotNull(if (trial) "7 gün ücretsiz" else null, state.annual?.perMonth()?.let { "ayda $it" }).joinToString(" · ")
        Plan.LIFETIME -> "Tek seferlik ödeme"
    }
    val cta = when (plan) {
        Plan.ANNUAL -> if (trial) "7 gün ücretsiz dene" else state.annual?.let { "Abone ol · ${it.price()}/yıl" } ?: "Abone ol"
        Plan.MONTHLY -> state.monthly?.let { "Abone ol · ${it.price()}/ay" } ?: "Abone ol"
        Plan.LIFETIME -> state.lifetime?.let { "Satın al · ${it.price()}" } ?: "Satın al"
    }
    val legal = when {
        plan == Plan.LIFETIME -> "Tek seferlik ödeme; abonelik değildir, yenilenmez. Satın alımın Geri yükle ile her cihazına gelir."
        plan == Plan.ANNUAL && trial -> "7 gün ücretsiz, sonra yılda ${state.annual?.price() ?: "yıllık ücret"}. Deneme bitmeden iptal edersen ücret alınmaz. Google Play › Abonelikler'den yönetilir."
        else -> "Abonelik, iptal edene kadar her dönem otomatik yenilenir. Google Play › Ödemeler ve abonelikler › Abonelikler'den istediğin zaman iptal edebilirsin."
    }

    Column(Modifier.fillMaxSize().background(c.background).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth()) {
            IconButton(onClick = { router.back() }, modifier = Modifier.align(Alignment.TopEnd).padding(end = 8.dp)) {
                Box(Modifier.size(34.dp).clip(CircleShape).background(c.surface2), contentAlignment = Alignment.Center) { Icon(Icons.Default.Close, "Kapat", tint = c.ink2) }
            }
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp), horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("KİLİT KELİME PRO", style = KelimeType.ui(12.sp, FontWeight.Bold).copy(letterSpacing = 1.2.sp), color = c.accent)
            Text(trigger.headline, style = KelimeType.english(32.sp).copy(letterSpacing = (-0.8).sp), color = c.ink, textAlign = TextAlign.Center)
            Text(subtitle(trigger), style = KelimeType.ui(13.sp), color = c.ink2, textAlign = TextAlign.Center)
            // Lock-screen preview.
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)).background(Brush.verticalGradient(listOf(c.accentSoft, c.surface)))
                    .border(1.dp, c.line, RoundedCornerShape(28.dp)).padding(vertical = 14.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("09:41", style = KelimeType.ui(50.sp, FontWeight.SemiBold), color = c.ink)
                AnimatedContent(tick, transitionSpec = { (slideInVertically { it } + fadeIn()) togetherWith fadeOut() }, label = "word") { t ->
                    val (en, tr) = words[t % words.size]
                    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).clip(RoundedCornerShape(16.dp)).background(c.surface2).padding(12.dp)) {
                        Text(en, style = KelimeType.english(22.sp), color = c.ink)
                        Text(tr, style = KelimeType.ui(13.sp), color = c.ink2)
                    }
                }
                Row(Modifier.padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Rate("Normal", "günde 4'e kadar", false, Modifier.weight(1f))
                    Rate("Çok sık", "günde 24'e kadar", true, Modifier.weight(1f))
                }
            }
            val f = focus(trigger)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                for (feature in features.filter { it.id == f } + features.filter { it.id != f }) {
                    val on = feature.id == f
                    Text(
                        feature.title, style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = if (on) c.onAccent else c.ink,
                        modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(if (on) c.accent else c.surface).border(1.dp, if (on) c.accent else c.line, RoundedCornerShape(12.dp))
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                    )
                }
            }
            Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (p in Plan.entries) {
                    val on = p == plan
                    Box(Modifier.weight(1f)) {
                        Column(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(if (on) c.accentSoft else c.surface)
                                .border(if (on) 2.dp else 1.dp, if (on) c.accent else c.line, RoundedCornerShape(16.dp)).clickable { plan = p }
                                .padding(vertical = 14.dp, horizontal = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Text(p.title, style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
                            Text(state.pkg(p)?.price() ?: "—", style = KelimeType.ui(18.sp, FontWeight.SemiBold), color = c.ink)
                            Text(note(p), style = KelimeType.ui(11.sp), color = c.ink2, textAlign = TextAlign.Center, minLines = 2, maxLines = 2)
                        }
                        if (p == Plan.ANNUAL) state.annualSaving?.let {
                            Text(
                                "%$it tasarruf", style = KelimeType.ui(10.sp, FontWeight.Bold), color = c.greenInk,
                                modifier = Modifier.align(Alignment.TopCenter).offset(y = (-9).dp).clip(CircleShape).background(c.greenBackground).padding(vertical = 3.dp, horizontal = 7.dp),
                            )
                        }
                    }
                }
            }
            if (!app.purchases.configured) Text("Satın alma bu sürümde henüz ayarlanmadı.", style = KelimeType.ui(12.sp), color = c.amberInk)
            state.error?.let { Text(it, style = KelimeType.ui(12.sp), color = c.amberInk) }
            Gap(8.dp)
        }
        Divider()
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(
                Modifier.fillMaxWidth().heightIn(min = 54.dp).clip(RoundedCornerShape(14.dp)).background(if (selected != null) c.accent else c.accent.copy(alpha = 0.5f))
                    .clickable(enabled = selected != null && !working) {
                        val p = selected ?: return@clickable
                        working = true
                        scope.launch {
                            when (app.purchases.purchase(activity, p)) {
                                PurchaseManager.Result.PENDING -> router.toast = "Ödeme bekleniyor; onaylanınca Pro açılır."
                                else -> {}
                            }
                            working = false
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                if (working) CircularProgressIndicator(color = c.onAccent, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
                else Text(cta, style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.onAccent)
            }
            Text(legal, style = KelimeType.ui(11.sp), color = c.ink2, textAlign = TextAlign.Center, minLines = 2)
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                Link("Geri yükle") { scope.launch { router.toast = if (app.purchases.restore()) "Pro geri yüklendi" else "Geri yüklenecek satın alma bulunamadı" } }
                Link("Koşullar") { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(TERMS_URL))) }
                Link("Gizlilik") { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_URL))) }
            }
        }
    }
}

@Composable
private fun Rate(title: String, detail: String, pro: Boolean, modifier: Modifier) {
    val c = Palette.current
    Box(modifier) {
        ProCorner(pro) {
            Column(
                Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(12.dp)).background(if (pro) c.surface else c.surface2.copy(alpha = 0.6f))
                    .border(1.dp, if (pro) c.accent else c.surface2.copy(alpha = 0f), RoundedCornerShape(12.dp)).padding(8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(title, style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink)
                Text(detail, style = KelimeType.ui(11.sp), color = c.ink2)
            }
        }
    }
}

@Composable
private fun Link(title: String, onClick: () -> Unit) {
    Text(title, style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = Palette.current.ink2, modifier = Modifier.clickable(onClick = onClick).padding(vertical = 6.dp))
}
