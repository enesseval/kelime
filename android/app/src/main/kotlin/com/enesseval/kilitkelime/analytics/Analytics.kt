package com.enesseval.kilitkelime.analytics

import android.app.Application
import com.enesseval.kilitkelime.BuildConfig
import com.telemetrydeck.sdk.TelemetryDeck

/**
 * Anonymous usage signals through TelemetryDeck, the same app id and signal names as iOS
 * (`Usage.<event>`), plus the Android and 1.1 ones. No advertising id, no account id.
 */
object Analytics {
    private const val APP_ID = "E70DAA36-B891-49C0-9F68-3DBD35E8643C"

    enum class Event {
        onboardingDone, widgetInstalled, quickReview, puzzle, wordDetail, units, filter, sort,
        examCountdown, listCreated, listShared, listImported, paywallShown, purchase, placementTest, signedIn,
        // Android
        notificationOn, tileAdded,
    }

    /** 1.1 signals (docs/V1_1_PLAN.md §5), same names on iOS and Android. */
    object Signal {
        const val STREAK_DAY = "streak.day"
        const val STREAK_FREEZE_USED = "streak.freezeUsed"
        const val WEEKLY_OPENED = "weekly.opened"
        const val WEEKLY_SHARED = "weekly.shared"
        const val SHARE_CARD = "share.card"
        const val TILE_QUICK_REVIEW = "tile.quickReview"
        const val WALLPAPER_ENABLED = "wallpaper.enabled"
        const val REMINDER_ASK = "reminder.ask"
        const val PAYWALL_MOMENT = "paywall.moment"
        // 1.2 (docs/V1_2_PLAN.md §2)
        const val TRIAL_STARTED = "trial.started"
        const val TRIAL_ENDED = "trial.ended"
    }

    fun start(app: Application) {
        val builder = TelemetryDeck.Builder().appID(APP_ID).showDebugLogs(false)
        if (BuildConfig.DEBUG) builder.testMode(true)
        TelemetryDeck.start(app, builder)
    }

    fun send(event: Event, parameters: Map<String, String> = emptyMap()) {
        runCatching { TelemetryDeck.signal("Usage.${event.name}", parameters) }
    }

    fun signal(name: String, parameters: Map<String, String> = emptyMap()) {
        runCatching { TelemetryDeck.signal(name, parameters) }
    }
}

/**
 * `Usage.widgetInstalled`, once per install, when a Kilit Kelime home-screen widget is first seen
 * (iOS sends it from Bugün once WidgetCenter reports a widget; key `usage.widgetSeen`). Checked at
 * launch and when a widget provider gets its first instance (onEnabled).
 */
object WidgetUsage {
    private const val KEY = "usage.widgetSeen"

    fun check(context: android.content.Context) {
        val prefs = context.getSharedPreferences("usage", android.content.Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY, false)) return
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        val installed = listOf(
            com.enesseval.kilitkelime.widget.CardWidgetReceiver::class.java,
            com.enesseval.kilitkelime.widget.QuizWidgetReceiver::class.java,
            com.enesseval.kilitkelime.widget.LargeWidgetReceiver::class.java,
        ).any { runCatching { manager.getAppWidgetIds(android.content.ComponentName(context, it)).isNotEmpty() }.getOrDefault(false) }
        if (!installed) return
        prefs.edit().putBoolean(KEY, true).apply()
        Analytics.send(Analytics.Event.widgetInstalled)
    }
}

