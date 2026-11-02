package com.enesseval.kilitkelime.ui.today

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.games.Streak
import com.enesseval.kilitkelime.core.queries.StatsQueries
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.Kicker
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SurfaceCard
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.components.TurkishDate
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.share.ShareCardSheet
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import com.enesseval.kilitkelime.ui.word.ShareCard

/** The streak page: current and longest, the freezes, and the last five weeks. */
@Composable
fun StreakScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val status by loadData(pro) { db -> Streak.status(db, app.model.clock, pro) }
    var sharing by remember { mutableStateOf<Int?>(null) }
    PushedScreen("Seri") {
        val s = status ?: return@PushedScreen
        Text("🔒 ${s.current} gün", style = KelimeType.english(52.sp), color = c.ink)
        Text(
            when {
                s.atRisk -> "Bugün henüz çalışmadın. Serin bu akşam bitmesin: 2 dakikalık bir tur yeter."
                s.current > 0 -> "Bugün çalıştın. Yarın görüşürüz."
                else -> "Hızlı Tekrar, bulmacada bir kelime ya da bir oyun seriyi başlatır."
            },
            style = KelimeType.ui(15.sp), color = if (s.atRisk) c.amberInk else c.ink2,
        )
        Gap(14.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SurfaceCard(Modifier.weight(1f)) {
                Text("${s.longest}", style = KelimeType.ui(24.sp, FontWeight.SemiBold), color = c.ink)
                Text("en uzun seri", style = KelimeType.ui(12.sp), color = c.ink2)
            }
            SurfaceCard(Modifier.weight(1f)) {
                Text("${s.freezesLeftThisWeek}", style = KelimeType.ui(24.sp, FontWeight.SemiBold), color = c.ink)
                Text("koruyucu bu hafta", style = KelimeType.ui(12.sp), color = c.ink2)
            }
        }
        Gap(8.dp)
        Text(
            "Seri koruyucu: haftada bir kaçırdığın tek günü otomatik kurtarır" + if (pro) " (Pro ile haftada 2)." else ". Pro ile haftada 2.",
            style = KelimeType.ui(13.sp), color = c.ink2,
        )
        Gap(18.dp)
        Kicker("SON 5 HAFTA")
        Gap(8.dp)
        val today = app.model.clock.today
        Row(Modifier.fillMaxWidth()) {
            for (initial in StatsQueries.weekdayInitials) Text(initial, style = KelimeType.ui(11.sp), color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
        }
        for (week in Streak.calendar(today)) {
            Row(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
                for (day in week) {
                    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        val studied = day in s.studied
                        val frozen = day in s.frozen
                        val future = day > today
                        Canvas(Modifier.size(22.dp).semantics {
                            contentDescription = TurkishDate.header(day) + when {
                                studied -> ", çalışıldı"
                                frozen -> ", koruyucuyla kurtarıldı"
                                else -> ""
                            }
                        }) {
                            val r = size.minDimension / 2
                            when {
                                studied -> drawCircle(c.green, r)
                                frozen -> drawCircle(c.green, r - 2.dp.toPx(), style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 5f))))
                                !future -> drawCircle(c.surface2, r - 1.dp.toPx(), style = Stroke(2.dp.toPx()))
                            }
                            if (day == today) drawCircle(c.accent, 3.dp.toPx())
                        }
                    }
                }
            }
        }
        Gap(18.dp)
        val milestone = Streak.milestones.lastOrNull { it <= s.current }
        if (milestone != null) {
            PrimaryButton("$milestone gün serini paylaş") { sharing = milestone }
        }
        if (s.atRisk) {
            Gap(8.dp)
            TintedButton("Hızlı Tekrar · 2 dk") { router.startQuickReview() }
        }
    }
    sharing?.let { days -> ShareCardSheet(ShareCard.Content.Milestone(days)) { sharing = null } }
}

/** The weekly summary (Mondays): last week's numbers, the word of the week, and Paylaş. */
@Composable
fun WeeklyScreen() {
    val app = LocalApp.current
    val c = Palette.current
    val pro by app.model.isPro.collectAsState()
    val summary by loadData(pro) { db -> StatsQueries.lastWeek(db, app.model.clock, pro) }
    var sharing by remember { mutableStateOf(false) }
    PushedScreen("Haftalık özet", close = true) {
        val s = summary ?: return@PushedScreen
        Kicker("${TurkishDate.header(s.weekStart).substringBefore(",")} HAFTASI".uppercase(com.enesseval.kilitkelime.ui.components.TR))
        Gap(10.dp)
        Text("${s.learned}", style = KelimeType.english(84.sp), color = c.ink)
        Text("kelime öğrendin", style = KelimeType.ui(17.sp, FontWeight.Medium), color = c.ink)
        Gap(16.dp)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Stat("${s.struggling}", "zorlanılan", c.amberInk, Modifier.weight(1f))
                Stat("${s.shown}", "kilit ekranında", c.ink, Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Stat(s.quickReviewAccuracy?.let { "%$it" } ?: "—", "Hızlı Tekrar doğruluğu", c.ink, Modifier.weight(1f))
                Stat("🔒 ${s.streak}", "gün seri", c.greenInk, Modifier.weight(1f))
            }
        }
        s.wordOfWeek?.let { w ->
            Gap(18.dp)
            SurfaceCard {
                Kicker("HAFTANIN KELİMESİ")
                Gap(6.dp)
                Text(w.word, style = KelimeType.english(34.sp), color = c.ink)
                Text(w.meaning, style = KelimeType.ui(15.sp), color = c.ink2)
                Text("En çok zorlandığın, sonunda öğrendiğin kelime.", style = KelimeType.ui(12.sp), color = c.ink2, modifier = Modifier.padding(top = 6.dp))
            }
        }
        Gap(20.dp)
        PrimaryButton("Paylaş") {
            Analytics.signal(Analytics.Signal.WEEKLY_SHARED)
            sharing = true
        }
    }
    val s = summary
    if (sharing && s != null) {
        ShareCardSheet(
            ShareCard.Content.Weekly(s.learned, s.streak, s.wordOfWeek, "${s.shown} kelime kilit ekranımda" + (s.quickReviewAccuracy?.let { " · %$it doğru" } ?: "")),
        ) { sharing = false }
    }
}

@Composable
private fun Stat(value: String, label: String, color: androidx.compose.ui.graphics.Color, modifier: Modifier) {
    val c = Palette.current
    SurfaceCard(modifier, padding = 14.dp) {
        Text(value, style = KelimeType.ui(22.sp, FontWeight.SemiBold), color = color)
        Text(label, style = KelimeType.ui(12.sp), color = c.ink2)
    }
}
