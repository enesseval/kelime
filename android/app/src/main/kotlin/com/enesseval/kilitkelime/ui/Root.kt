package com.enesseval.kilitkelime.ui

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.data.StartupStep
import com.enesseval.kilitkelime.ui.components.ThinProgressBar
import com.enesseval.kilitkelime.ui.onboarding.OnboardingFlow
import com.enesseval.kilitkelime.ui.theme.KelimeType
import com.enesseval.kilitkelime.ui.theme.Palette

val LocalApp = staticCompositionLocalOf<KilitKelimeApp> { error("no app") }
val LocalActivity = staticCompositionLocalOf<MainActivity> { error("no activity") }

/** Reads from the database and reloads whenever data changes (iOS `model.read` + dataVersion). */
@Composable
fun <T> loadData(vararg keys: Any?, block: (SqlDb) -> T): State<T?> {
    val app = LocalApp.current
    val version by app.model.dataVersion.collectAsState()
    return produceState<T?>(null, version, *keys) {
        value = runCatching { app.model.read(block) }.getOrNull()
    }
}

@Composable
fun Root(activity: MainActivity, app: KilitKelimeApp) {
    CompositionLocalProvider(LocalApp provides app, LocalActivity provides activity) {
        val startup by app.model.startup.collectAsState()
        val onboardingDone by app.model.onboardingDone.collectAsState()
        val state = when {
            startup.first != StartupStep.READY -> 0
            onboardingDone == false -> 1
            else -> 2
        }
        Crossfade(targetState = state, label = "root") { s ->
            when (s) {
                0 -> LaunchScreen(startup.first, startup.second)
                1 -> OnboardingFlow()
                else -> MainScaffold()
            }
        }
    }
}

@Composable
private fun LaunchScreen(step: StartupStep, progress: Double) {
    val c = Palette.current
    Box(Modifier.fillMaxSize().background(c.background), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("Kilit Kelime", style = KelimeType.english(40.sp), color = c.ink)
            if (step == StartupStep.IMPORT_CONTENT) {
                Text(step.title, style = KelimeType.ui(14.sp, FontWeight.Medium), color = c.ink2)
                ThinProgressBar(progress, Modifier.width(180.dp).padding(top = 4.dp), c.accent)
            }
        }
    }
}
