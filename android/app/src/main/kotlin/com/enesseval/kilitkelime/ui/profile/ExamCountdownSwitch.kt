package com.enesseval.kilitkelime.ui.profile

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import com.enesseval.kilitkelime.lock.WordNotification
import com.enesseval.kilitkelime.ui.LocalApp
import com.enesseval.kilitkelime.ui.LocalRouter
import kotlinx.coroutines.launch

/**
 * Turns the exam countdown notification on or off (docs/V1_2_PLAN.md §5). Without Pro (and no trial) it
 * opens the exam-plan paywall; on Android 13+ turning it on asks for the notification permission first.
 */
@Composable
fun rememberExamCountdownSetter(): (Boolean) -> Unit {
    val app = LocalApp.current
    val router = LocalRouter.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) scope.launch {
            app.model.prefs.update { it.copy(examNotificationEnabled = true) }
            app.lockScreen.refresh("exam-notification-on")
        }
    }
    return { on ->
        when {
            on && !app.model.isPro.value -> router.showPaywall(PaywallTrigger.EXAM_PLAN)
            on && Build.VERSION.SDK_INT >= 33 && !WordNotification.canPost(context) -> {
                permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                scope.launch { app.model.prefs.update { it.copy(notificationsRequested = true) } }
            }
            else -> scope.launch {
                app.model.prefs.update { it.copy(examNotificationEnabled = on) }
                app.lockScreen.refresh("exam-notification-$on")
            }
        }
    }
}
