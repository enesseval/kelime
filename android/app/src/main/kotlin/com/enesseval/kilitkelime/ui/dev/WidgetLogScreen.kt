package com.enesseval.kilitkelime.ui.dev

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.widgets.WidgetLog
import com.enesseval.kilitkelime.lock.RotationScheduler
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.TintedButton
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Geliştirici › Widget günlüğü: every wallpaper/widget update and tap, with whether the word on
 * screen was the scheduled one and how late. Used to measure real update times on devices.
 */
@Composable
fun WidgetLogScreen() {
    val app = LocalApp.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val rows by loadData { db -> WidgetLog.recent(db) }
    val format = DateTimeFormatter.ofPattern("dd.MM HH:mm:ss").withZone(ZoneId.systemDefault())
    PushedScreen("Widget günlüğü") {
        val list = rows ?: return@PushedScreen
        val updates = list.filter { it.source == "wallpaper" && it.onTime != null }
        val late = updates.mapNotNull { it.lag }
        Text("Duvar kâğıdı: ${updates.size} güncelleme, ${updates.count { it.onTime == true }} zamanında" +
            (if (late.isNotEmpty()) ", en geç ${late.maxOf { it.toMinutes() }} dk" else ""), style = KelimeType.ui(14.sp, FontWeight.SemiBold), color = c.ink)
        Text("Tam zamanlı alarm: " + if (RotationScheduler.canScheduleExact(app)) "izinli" else "izin yok (WorkManager, gecikebilir)", style = KelimeType.ui(13.sp), color = c.ink2)
        Gap(10.dp)
        Row {
            TintedButton("Şimdi yenile", fullWidth = false) { scope.launch { app.lockScreen.redrawWallpaper() } }
            Gap(0.dp)
            TintedButton("Temizle", fullWidth = false, modifier = Modifier.padding(start = 8.dp)) { scope.launch { app.model.write("log-clear") { db -> WidgetLog.clear(db) } } }
        }
        Gap(12.dp)
        for (row in list) {
            Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                Text("${format.format(row.at)} · ${row.kind.raw} · ${row.source}", style = KelimeType.ui(13.sp, FontWeight.SemiBold), color = c.ink)
                val status = when (row.onTime) {
                    true -> "zamanında"
                    false -> "geç" + (row.lag?.let { " ${it.toMinutes()} dk" } ?: "")
                    null -> ""
                }
                Text(listOf(row.detail, row.shownCardID ?: "", status).filter { it.isNotEmpty() }.joinToString(" · "), style = KelimeType.ui(12.sp), color = c.ink2)
                row.reloadAt?.let { Text("sonraki: ${format.format(it)}", style = KelimeType.ui(12.sp), color = c.ink2) }
            }
            Divider()
        }
    }
}
