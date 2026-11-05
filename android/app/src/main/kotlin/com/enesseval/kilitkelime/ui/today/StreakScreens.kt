package com.enesseval.kilitkelime.ui.today

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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.AcUnit
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.EventAvailable
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Widgets
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.games.Streak
import com.enesseval.kilitkelime.core.games.StreakStatus
import com.enesseval.kilitkelime.core.queries.StatsQueries
import com.enesseval.kilitkelime.core.queries.WeeklySummary
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.share.ShareCardSheet
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.word.ShareCard
import java.time.LocalDate

/** Bugün's streak chip (iOS StreakBadge): lock and "12 gün", amber while today still needs a round. */
@Composable
fun StreakBadge(status: StreakStatus, onClick: () -> Unit) {
    val c = Palette.current
    val ink = if (status.atRisk) c.amberInk else c.ink
    Row(
        Modifier.clip(CircleShape)
            .background(if (status.atRisk) c.amberBackground else c.surface)
            .then(if (status.atRisk) Modifier else Modifier.border(1.dp, c.line, CircleShape))
            .clickable(onClick = onClick)
            .padding(vertical = 7.dp, horizontal = 11.dp)
            .clearAndSetSemantics {
                contentDescription = if (status.atRisk) "Seri ${status.current} gün, bugün henüz çalışmadın" else "Seri ${status.current} gün"
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(if (status.studiedToday) Icons.Outlined.Lock else Icons.Outlined.LockOpen, null, tint = ink, modifier = Modifier.size(13.dp))
        Text("${status.current} gün", style = KelimeType.ui(12.sp, FontWeight.SemiBold), color = ink)
    }
}

/** The streak page (iOS StreakView): current and longest streak, five weeks, how it works. */
@Composable
fun StreakScreen() {
    val app = LocalApp.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val status by loadData(pro) { db -> Streak.status(db, app.model.clock, pro) }
    var sharing by remember { mutableStateOf(false) }
    PushedScreen("Seri") {
        val s = status ?: return@PushedScreen
        Gap(12.dp)
        Text("${s.current}", style = KelimeType.english(88.sp).copy(letterSpacing = (-2).sp), color = c.ink)
        Text(
            if (s.current == 0) "Bugün bir tur yap, serin başlasın." else "günlük seri",
            style = KelimeType.ui(17.sp, FontWeight.SemiBold), color = c.ink,
        )
        val subtitle = when {
            s.atRisk -> "Bugün henüz çalışmadın. 2 dakikalık bir tur serini korur."
            s.longest > s.current -> "En uzun serin: ${s.longest} gün"
            s.current > 0 -> "Bu senin en uzun serin."
            else -> ""
        }
        if (subtitle.isNotEmpty()) {
            Gap(4.dp)
            Text(subtitle, style = KelimeType.ui(14.sp), color = if (s.atRisk) c.amberInk else c.ink2)
        }
        Gap(20.dp)
        SurfaceCard(padding = 16.dp) { StreakCalendar(s, app.model.clock.today) }
        Gap(20.dp)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Rule(Icons.Outlined.CheckCircle, "Bir Hızlı Tekrar turu, Günün Bulmacası'nda bir kelime ya da bir oyun günü sayar.")
            Rule(Icons.Outlined.AcUnit, "Haftada ${Streak.freezesPerWeek(pro)} gün kaçırırsan serin bozulmaz; o gün kesik çizgiyle görünür.")
            Rule(Icons.Outlined.Widgets, "Widget'a bakmak seriyi saymaz ama kelimeleri o öğretir.")
        }
        if (s.current > 0) {
            Gap(20.dp)
            TintedButton("Serini paylaş", height = 48.dp) { sharing = true }
        }
    }
    val s = status
    if (sharing && s != null) {
        ShareCardSheet(ShareCard.Content.Streak(s.current, s.studied, s.frozen, app.model.clock.today)) { sharing = false }
    }
}

@Composable
private fun Rule(icon: ImageVector, text: String) {
    val c = Palette.current
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(icon, null, tint = c.ink2, modifier = Modifier.padding(top = 1.dp).size(18.dp))
        Text(text, style = KelimeType.ui(14.sp), color = c.ink2)
    }
}

/** Five weeks, Monday first (iOS StreakCalendar): filled = studied, dashed ring = freeze. */
@Composable
fun StreakCalendar(status: StreakStatus, today: LocalDate, dot: Dp = 30.dp) {
    val c = Palette.current
    val initials = listOf("P", "S", "Ç", "P", "C", "C", "P")
    Column(
        Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = "Son beş haftada ${status.studied.size} gün çalıştın" },
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(Modifier.fillMaxWidth()) {
            for (initial in initials) {
                Text(initial, style = KelimeType.ui(11.sp, FontWeight.SemiBold), color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            }
        }
        for (week in Streak.calendar(today)) {
            Row(Modifier.fillMaxWidth()) {
                for (day in week) {
                    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        val studied = day in status.studied
                        val frozen = day in status.frozen
                        Canvas(Modifier.size(dot)) {
                            val r = size.minDimension / 2
                            when {
                                studied -> drawCircle(c.green, r)
                                frozen -> drawCircle(
                                    c.ink2, r - 0.75.dp.toPx(),
                                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))),
                                )
                                day > today -> Unit
                                else -> drawCircle(c.surface2, r)
                            }
                            if (day == today) drawCircle(c.accent, r + 2.dp.toPx(), style = Stroke(2.dp.toPx()))
                        }
                    }
                }
            }
        }
    }
}

/** Monday's look back at last week (iOS WeeklySummaryView), with a share button. */
@Composable
fun WeeklyScreen() {
    val app = LocalApp.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val summary by loadData(pro) { db -> StatsQueries.lastWeek(db, app.model.clock, pro) }
    var sharing by remember { mutableStateOf(false) }
    PushedScreen("Geçen hafta", close = true) {
        val s = summary ?: return@PushedScreen
        Gap(8.dp)
        Text(ShareCard.range(s.weekStart), style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink2)
        Gap(18.dp)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("${s.learned}", style = KelimeType.english(72.sp).copy(letterSpacing = (-1.5).sp), color = c.ink)
            Text("kelime öğrendin", style = KelimeType.ui(18.sp, FontWeight.SemiBold), color = c.ink, modifier = Modifier.padding(bottom = 14.dp))
        }
        Gap(18.dp)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Equal heights per row: a long label never leaves its neighbour short.
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Stat("${s.shown}", "kelime kilit ekranında göründü", Modifier.weight(1f))
                Stat("${s.streak} gün", "seri", Modifier.weight(1f))
            }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Stat(s.quickReviewAccuracy?.let { "%$it" } ?: "–", "Hızlı Tekrar doğruluğu", Modifier.weight(1f))
                Stat("${s.struggling}", "kelimede zorlandın", Modifier.weight(1f))
            }
        }
        s.wordOfWeek?.let { w ->
            Gap(18.dp)
            SurfaceCard(padding = 16.dp) {
                Text("HAFTANIN KELİMESİ", style = KelimeType.ui(11.sp, FontWeight.SemiBold).copy(letterSpacing = 0.9.sp), color = c.ink2)
                Gap(4.dp)
                Text(w.word, style = KelimeType.english(34.sp), color = c.ink)
                Text("${w.pos.label} · ${w.meaning}", style = KelimeType.ui(15.sp), color = c.ink2)
                Gap(4.dp)
                Text("Önce zorlandın, sonunda öğrendin.", style = KelimeType.ui(13.sp), color = c.greenInk)
            }
        }
        Gap(18.dp)
        PrimaryButton("Haftanı paylaş", height = 52.dp) {
            sharing = true
            Analytics.signal(Analytics.Signal.WEEKLY_SHARED)
        }
    }
    val s = summary
    LaunchedEffect(s != null) {
        if (s != null) app.model.prefs.update { it.copy(lastWeeklySummary = s.weekStart.toString()) }
    }
    if (sharing && s != null) {
        ShareCardSheet(ShareCard.Content.Weekly(s.weekStart, s.learned, s.shown, s.streak, s.wordOfWeek)) { sharing = false }
    }
}

@Composable
private fun Stat(value: String, label: String, modifier: Modifier) {
    val c = Palette.current
    SurfaceCard(modifier.fillMaxHeight(), padding = 14.dp) {
        Text(value, style = KelimeType.ui(22.sp, FontWeight.Bold), color = c.ink)
        Gap(2.dp)
        Text(label, style = KelimeType.ui(13.sp), color = c.ink2)
    }
}

/** Bugün's Monday card that opens last week's summary (iOS WeeklySummaryCard). */
@Composable
fun WeeklySummaryCard(summary: WeeklySummary, onOpen: () -> Unit) {
    val c = Palette.current
    SurfaceCard(onClick = onOpen, padding = 16.dp) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(44.dp).clip(CircleShape).background(c.accentSoft), contentAlignment = Alignment.Center) {
                Icon(Icons.Outlined.EventAvailable, null, tint = c.accent, modifier = Modifier.size(22.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("Geçen haftan hazır", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink)
                Text("${summary.learned} kelime öğrendin · ${summary.shown} kelime kilit ekranında", style = KelimeType.ui(13.sp), color = c.ink2)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.ink2)
        }
    }
}
