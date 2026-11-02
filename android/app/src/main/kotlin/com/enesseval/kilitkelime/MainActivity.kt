package com.enesseval.kilitkelime

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.enesseval.kilitkelime.ui.Root
import com.enesseval.kilitkelime.ui.theme.KelimeTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    /** The last deep link (widget, notification, tile, shared list), consumed by the router. */
    val links = MutableStateFlow<Intent?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        val app = application as KilitKelimeApp
        installSplashScreen().setKeepOnScreenCondition { !app.model.isOpen && app.model.startup.value.second == 0.0 }
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        links.value = intent
        setContent {
            KelimeTheme { Root(this, app) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        links.value = intent
    }

    override fun onResume() {
        super.onResume()
        val app = application as KilitKelimeApp
        // The slot may have changed while the app was away; also pick up a new day.
        app.model.scope.launch {
            if (app.model.isOpen) app.model.changed("resume")
            app.account.sync()
        }
    }
}
