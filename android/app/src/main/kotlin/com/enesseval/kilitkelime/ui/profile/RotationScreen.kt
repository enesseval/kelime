package com.enesseval.kilitkelime.ui.profile

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.RotationInterval
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import com.enesseval.kilitkelime.ui.components.Divider
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.ProBadge
import com.enesseval.kilitkelime.ui.components.PushedScreen
import com.enesseval.kilitkelime.ui.components.SettingsRow
import com.enesseval.kilitkelime.ui.components.SettingsSection
import com.enesseval.kilitkelime.ui.loadData
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch

/** Değişim sıklığı: Normal is free; Sık and Çok sık are Pro. */
@Composable
fun RotationScreen() {
    val app = LocalApp.current
    val router = LocalRouter.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    val pro by app.model.isPro.collectAsState()
    val prefs by loadData { db -> Preferences.load(db) }
    PushedScreen("Değişim sıklığı") {
        Text(
            "Kilit ekranındaki kelimenin ne sıklıkla yenileneceğini seç. Android, pil tasarrufu için güncellemeyi birkaç dakika geciktirebilir.",
            style = KelimeType.ui(14.sp), color = c.ink2,
        )
        Gap(14.dp)
        val selected = prefs?.effectiveRotation ?: RotationInterval.DEFAULT
        SettingsSection("SIKLIK") {
            listOf(RotationInterval.THREE_HOURS, RotationInterval.ONE_HOUR, RotationInterval.THIRTY_MINUTES).forEachIndexed { i, interval ->
                if (i > 0) Divider()
                val locked = interval != RotationInterval.THREE_HOURS && !pro
                SettingsRow(rotationTitle(interval), rotationDetail(interval), onClick = {
                    if (locked) router.showPaywall(PaywallTrigger.ROTATION) else scope.launch {
                        app.model.writeAndRequeue("rotation") { db -> Preferences.load(db).copy(rotationInterval = interval).save(db) }
                    }
                }) {
                    when {
                        locked -> ProBadge()
                        interval == selected -> Text("✓", style = KelimeType.ui(16.sp, FontWeight.Bold), color = c.accent)
                    }
                }
            }
        }
    }
}
