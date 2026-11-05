package com.enesseval.kilitkelime.ui.paywall

import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.automirrored.outlined.ListAlt
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material.icons.outlined.Explore
import androidx.compose.material.icons.outlined.EventNote
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.outlined.Extension
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.graphics.Color
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

private data class Feature(val id: String, val icon: ImageVector, val title: String, val detail: String)

/** What Pro adds (iOS PaywallView.features). Everything else stays free. */
private val features = listOf(
    Feature("lists", Icons.AutoMirrored.Outlined.ListAlt, "Sınırsız kendi listen", "İstediğin kadar liste, hepsi widget'ta"),
    Feature("share", Icons.Outlined.IosShare, "Listeni paylaş", "Linkle gönder ya da Keşfet'te herkese aç"),
    Feature("discover", Icons.Outlined.Explore, "Keşfet'ten hazır listeler", "Başkalarının listelerini tek dokunuşla ekle"),
    Feature("exam", Icons.Outlined.EventNote, "Sınav planı", "Sınav gününe göre günlük kelime hedefi"),
    Feature("rotation", Icons.Filled.Bolt, "Daha sık yeni kelime", "Widget'ta günde 24'e kadar kelime"),
    Feature("puzzle", Icons.Outlined.Extension, "Sana özel bulmaca", "Zorlandıklarınla; bulmaca arşivi de açılır"),
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
    PaywallTrigger.SHARE -> "Listeni gönder; açan herkes kendi widget'ına ekler."
    PaywallTrigger.ROTATION -> "Kilit ekranında gün boyu daha çok kelime."
    PaywallTrigger.PERSONAL_PUZZLE -> "Zorlandığın ve öğrendiğin kelimelerden karışık bir bulmaca."
    PaywallTrigger.ARCHIVE -> "Kaçırdığın günlerin bulmacalarını çöz."
    PaywallTrigger.EXAM_PLAN -> "Sınav gününe kadar her gün kaç kelime çalışman gerektiğini görelim."
    PaywallTrigger.DISCOVER -> "Diğer öğrencilerin hazırladığı listeleri ekle; widget'ında ve Hızlı Tekrar'da dönsün."
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

/** iOS OnboardingSky at night (the paywall's background): deep blue gradient, a fixed star field, the moon. */
@Composable
fun NightSky(modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxSize()) {
        drawRect(Brush.verticalGradient(listOf(Color(0xFF080D24), Color(0xFF141738), Color(0xFF241F45))))
        var state = 7uL
        fun next(): ULong { state = state * 6364136223846793005uL + 1442695040888963407uL; return state shr 33 }
        repeat(70) {
            val x = (next() % 1000uL).toFloat() / 1000f * size.width
            val y = (next() % 1000uL).toFloat() / 1000f * size.height * 0.6f
            val r = ((next() % 3uL).toFloat() + 1f) * 0.6f * density / 2f
            val alpha = 0.35f + (next() % 60uL).toFloat() / 100f
            drawCircle(Color.White.copy(alpha = alpha.coerceAtMost(1f)), r, Offset(x, y))
        }
        val moon = Offset(size.width * 0.8f, size.height * 0.12f)
        drawCircle(Color(0xFFF2F0DB), 17.dp.toPx(), moon)
        drawCircle(Color(0xFF080D24), 15.dp.toPx(), moon + Offset(10.dp.toPx(), -6.dp.toPx()))
        drawRect(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.55f)), startY = size.height / 2, endY = size.height))
    }
}

/**
 * The Pro paywall (port of `PaywallView.swift`): a night sky, the reason it opened first, what Pro
 * adds as tiles, the three plans as rows with the annual one chosen, and under the button what is
 * billed and when (Google Play subscription disclosure). Never shown on first launch.
 */
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
    var appeared by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { appeared = true; app.purchases.loadProducts() }
    LaunchedEffect(pro) { if (pro) router.back() }

    val selected = state.pkg(plan)
    val trial = state.annual?.hasTrial() == true
    val annualNote = listOfNotNull(if (trial) "7 gün ücretsiz, sonra yıllık" else "Yıllık yenilenir", state.annual?.perMonth()?.let { "ayda $it" }).joinToString(" · ")
    val cta = when (plan) {
        Plan.ANNUAL -> if (trial) "7 gün ücretsiz dene" else state.annual?.let { "Abone ol · ${it.price()}/yıl" } ?: "Abone ol"
        Plan.MONTHLY -> state.monthly?.let { "Abone ol · ${it.price()}/ay" } ?: "Abone ol"
        Plan.LIFETIME -> state.lifetime?.let { "Satın al · ${it.price()}" } ?: "Satın al"
    }
    // Store-specific wording (Google Play), two lines for every plan so the button doesn't move.
    val legal = when {
        plan == Plan.LIFETIME -> "Tek seferlik ödeme; abonelik değildir, yenilenmez. Satın alımın Geri yükle ile her cihazına gelir."
        plan == Plan.ANNUAL && trial -> "7 gün ücretsiz, sonra yılda ${state.annual?.price() ?: "yıllık ücret"}. Deneme bitmeden iptal edersen ücret alınmaz. Google Play › Abonelikler'den yönetilir."
        else -> "Abonelik, iptal edene kadar her dönem otomatik yenilenir. Google Play › Ödemeler ve abonelikler › Abonelikler'den istediğin zaman iptal edebilirsin."
    }
    val white = Color.White
    val f = focus(trigger)
    val ordered = features.filter { it.id == f } + features.filter { it.id != f }

    Box(Modifier.fillMaxSize().background(Color(0xFF080D24))) {
        NightSky()
        Column(Modifier.fillMaxSize()) {
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 20.dp).padding(top = 40.dp, bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(22.dp),
            ) {
                // Hero: a glow and a sparkle, the kicker, the headline and the reason.
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    val glow by animateFloatAsState(if (appeared) 1f else 0.6f, spring(dampingRatio = 0.7f, stiffness = 60f), label = "glow")
                    Box(Modifier.height(64.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Canvas(Modifier.size(110.dp).scale(glow)) {
                            drawCircle(Brush.radialGradient(listOf(c.accent.copy(alpha = 0.65f), Color.Transparent), radius = 70.dp.toPx()))
                        }
                        Text("✦", style = KelimeType.ui(30.sp, FontWeight.SemiBold), color = white)
                    }
                    Text("KİLİT KELİME PRO", style = KelimeType.ui(12.sp, FontWeight.Bold).copy(letterSpacing = 1.4.sp), color = c.accent)
                    Text(trigger.headline, style = KelimeType.english(34.sp).copy(letterSpacing = (-0.8).sp), color = white, textAlign = TextAlign.Center)
                    Text(subtitle(trigger), style = KelimeType.ui(15.sp), color = white.copy(alpha = 0.75f), textAlign = TextAlign.Center)
                }
                // Features: two columns of tiles; the reason the paywall opened comes first, in blue.
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ordered.chunked(2).forEachIndexed { row, pair ->
                        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            pair.forEachIndexed { column, feature ->
                                val index = row * 2 + column
                                val shown by animateFloatAsState(if (appeared) 1f else 0f, tween(400, delayMillis = 60 * index), label = "tile")
                                FeatureTile(feature, highlighted = feature.id == f, Modifier.weight(1f).fillMaxHeight().alpha(shown).offset(y = (12 * (1 - shown)).dp))
                            }
                        }
                    }
                }
                // Plans: rows, the annual one chosen and badged.
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    PlanRow("Aylık", state.monthly?.price(), "Her ay yenilenir, istediğin zaman iptal et", null, plan == Plan.MONTHLY, state.loading) { plan = Plan.MONTHLY }
                    PlanRow("Yıllık", state.annual?.price(), annualNote, state.annualSaving?.let { "%$it tasarruf" } ?: "En avantajlı", plan == Plan.ANNUAL, state.loading) { plan = Plan.ANNUAL }
                    PlanRow("Ömür boyu", state.lifetime?.price(), "Tek seferlik ödeme, abonelik yok", null, plan == Plan.LIFETIME, state.loading) { plan = Plan.LIFETIME }
                }
                if (state.packages.isEmpty() && !state.loading) {
                    Text(
                        "Fiyatlar yüklenemedi · Tekrar dene", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.accent, textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 32.dp).clickable { scope.launch { app.purchases.loadProducts() } }.wrapContentHeight(),
                    )
                }
            }
            // Footer: the button, the billing line, and Geri yükle · Koşullar · Gizlilik.
            Column(
                Modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f), Color.Black)))
                    .navigationBarsPadding().padding(horizontal = 20.dp).padding(top = 24.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).background(c.accent).alpha(if (selected == null) 0.6f else 1f)
                        .clickable(enabled = selected != null && !working) {
                            val p = selected ?: return@clickable
                            working = true
                            scope.launch {
                                when (app.purchases.purchase(activity, p)) {
                                    PurchaseManager.Result.PENDING -> router.toast = "Satın alma onay bekliyor"
                                    PurchaseManager.Result.CANCELLED -> state.error?.let { router.toast = it }
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
                Text(legal, style = KelimeType.ui(11.sp), color = white.copy(alpha = 0.6f), textAlign = TextAlign.Center, minLines = 2, maxLines = 3)
                Row(Modifier.heightIn(min = 30.dp), horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.CenterVertically) {
                    Link("Geri yükle") {
                        scope.launch { router.toast = if (app.purchases.restore()) "Pro geri yüklendi" else (app.purchases.state.value.error ?: "Geri yüklenecek satın alma bulunamadı") }
                    }
                    Link("Koşullar") { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(TERMS_URL))) }
                    Link("Gizlilik") { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_URL))) }
                }
            }
        }
        // Close: a small frosted circle, top right.
        Box(Modifier.statusBarsPadding().padding(horizontal = 12.dp, vertical = 8.dp).align(Alignment.TopEnd)) {
            Box(
                Modifier.size(44.dp).clickable { router.back() }.semantics { contentDescription = "Kapat" },
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Close, null, tint = white.copy(alpha = 0.9f), modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

@Composable
private fun FeatureTile(feature: Feature, highlighted: Boolean, modifier: Modifier) {
    val c = Palette.current
    Row(
        modifier.heightIn(min = 54.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.08f))
            .border(1.dp, if (highlighted) c.accent.copy(alpha = 0.8f) else Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp))
            .padding(10.dp).semantics(mergeDescendants = true) { stateDescription = feature.detail },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier.size(30.dp).clip(RoundedCornerShape(9.dp)).background(if (highlighted) c.accent else c.accent.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) { Icon(feature.icon, null, tint = if (highlighted) c.onAccent else c.accent, modifier = Modifier.size(16.dp)) }
        Text(feature.title, style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = Color.White, maxLines = 2)
    }
}

@Composable
private fun PlanRow(title: String, price: String?, note: String, badge: String?, selected: Boolean, loading: Boolean, onClick: () -> Unit) {
    val c = Palette.current
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(if (selected) c.accent.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.08f))
            .border(if (selected) 2.dp else 1.dp, if (selected) c.accent else Color.White.copy(alpha = 0.1f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick).padding(16.dp).semantics { this.selected = selected },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(
            if (selected) Icons.Filled.CheckCircle else Icons.Outlined.Circle, null,
            tint = if (selected) c.accent else Color.White.copy(alpha = 0.4f), modifier = Modifier.size(24.dp),
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(title, style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = Color.White)
                badge?.let {
                    Text(it, style = KelimeType.ui(11.sp, FontWeight.Bold), color = c.onAccent, modifier = Modifier.clip(CircleShape).background(c.green).padding(vertical = 3.dp, horizontal = 7.dp))
                }
            }
            Text(note, style = KelimeType.ui(12.sp), color = Color.White.copy(alpha = 0.7f))
        }
        when {
            price != null -> Text(price, style = KelimeType.ui(18.sp, FontWeight.Bold), color = Color.White)
            loading -> CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
            else -> Text("—", style = KelimeType.ui(18.sp, FontWeight.Bold), color = Color.White.copy(alpha = 0.5f))
        }
    }
}

@Composable
private fun Link(title: String, onClick: () -> Unit) {
    Text(title, style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = Color.White.copy(alpha = 0.7f), modifier = Modifier.clickable(onClick = onClick).padding(vertical = 6.dp))
}
