package com.enesseval.kilitkelime.notifications

import android.Manifest
import android.app.Activity
import android.app.TimePickerDialog
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.data.AppModel
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.components.Gap
import com.enesseval.kilitkelime.ui.components.PrimaryButton
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette
import kotlinx.coroutines.launch

/**
 * Asks for the daily reminder after a good moment (a finished Quick Review, a solved crossword
 * word, a finished game) instead of during onboarding (port of `ReminderAsk.swift`). Our card comes
 * first; the system prompt only opens when the learner taps "Hatırlat".
 */
object ReminderAsk {
    /** At most this many cards, at least three days apart. */
    const val MAX_ASKS = 2
    const val DAYS_BETWEEN_MS = 3L * 24 * 3600 * 1000
    const val DEFAULT_MINUTES = 20 * 60 + 30

    /**
     * True while the system has never been asked (Android 13+: POST_NOTIFICATIONS not granted and
     * not permanently denied, see [permanentlyDenied]; below 13: notifications on and no reminder
     * set yet) and our card hasn't been shown too often or too recently.
     */
    suspend fun shouldAsk(context: Context, model: AppModel, now: Long = System.currentTimeMillis()): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return false
        } else {
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
            if (model.read { db -> Settings.int(db, SettingKey.REMINDER_TIME) } != null) return false
        }
        val prefs = model.prefs.current()
        if (prefs.reminderAskCount >= MAX_ASKS) return false
        if (prefs.reminderAskLast > 0 && now - prefs.reminderAskLast < DAYS_BETWEEN_MS) return false
        return true
    }

    /**
     * Android can't say "never asked", so the app remembers when it opened the prompt: asked
     * before, still not granted and no rationale to show means "don't ask again" was chosen.
     */
    suspend fun permanentlyDenied(activity: Activity, model: AppModel): Boolean {
        if (Build.VERSION.SDK_INT < 33) return false
        return model.prefs.current().notificationsRequested &&
            !activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
    }

    suspend fun noteAsked(model: AppModel, now: Long = System.currentTimeMillis()) {
        model.prefs.update { it.copy(reminderAskCount = it.reminderAskCount + 1, reminderAskLast = now) }
    }
}

/** The card after a good moment: a time, "Hatırlat" (then the system prompt) or "Şimdi değil". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReminderAskSheet(onDismiss: () -> Unit) {
    val app = LocalApp.current
    val context = LocalContext.current
    val c = Palette.current
    val scope = rememberCoroutineScope()
    var minutes by remember { mutableIntStateOf(ReminderAsk.DEFAULT_MINUTES) }
    var asking by remember { mutableStateOf(false) }
    var answered by remember { mutableStateOf(false) }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    LaunchedEffect(Unit) { ReminderAsk.noteAsked(app.model) }

    fun finish(result: String) {
        if (answered) return
        answered = true
        Analytics.signal(Analytics.Signal.REMINDER_ASK, mapOf("result" to result))
        scope.launch { sheet.hide() }.invokeOnCompletion { onDismiss() }
    }

    fun granted(ok: Boolean) {
        scope.launch {
            if (ok) {
                app.model.write("reminder") { db -> Settings.setInt(db, SettingKey.REMINDER_TIME, minutes) }
                Reminder.schedule(context, minutes)
            }
            finish(if (ok) "granted" else "denied")
        }
    }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> granted(ok) }

    ModalBottomSheet(onDismissRequest = { finish("later") }, sheetState = sheet, containerColor = c.background) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 24.dp).padding(bottom = 16.dp)) {
            Box(Modifier.size(52.dp).clip(CircleShape).background(c.accentSoft), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.NotificationsActive, contentDescription = null, tint = c.accent, modifier = Modifier.size(26.dp))
            }
            Gap(18.dp)
            Text("Güzel bir tur oldu", style = KelimeType.english(30.sp), color = c.ink)
            Gap(8.dp)
            Text(
                "Yarın da aynı saatte 2 dakikalık bir tur hatırlatalım mı? Günde bir bildirim, başka bir şey yok.",
                style = KelimeType.ui(15.sp), color = c.ink2,
            )
            Gap(18.dp)
            Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(c.surface)
                    .clickable { TimePickerDialog(context, { _, h, m -> minutes = h * 60 + m }, minutes / 60, minutes % 60, true).show() }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Saat", style = KelimeType.ui(16.sp, FontWeight.SemiBold), color = c.ink, modifier = Modifier.weight(1f))
                Text(Reminder.label(minutes), style = KelimeType.ui(20.sp, FontWeight.SemiBold), color = c.accent)
            }
            Gap(22.dp)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                PrimaryButton(if (asking) "…" else "Hatırlat", height = 52.dp, enabled = !asking) {
                    asking = true
                    if (Build.VERSION.SDK_INT >= 33) {
                        scope.launch { app.model.prefs.update { it.copy(notificationsRequested = true) } }
                        permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        granted(true)
                    }
                }
                Box(
                    Modifier.fillMaxWidth().heightIn(min = 44.dp).clickable { finish("later") },
                    contentAlignment = Alignment.Center,
                ) { Text("Şimdi değil", style = KelimeType.ui(15.sp, FontWeight.SemiBold), color = c.ink2) }
            }
        }
    }
}
