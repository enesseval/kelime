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
    }

    fun start(app: Application) {
        val builder = TelemetryDeck.Builder().appID(APP_ID).showDebugLogs(false)
        if (BuildConfig.DEBUG) builder.testMode(true)
        TelemetryDeck.start(app, builder)
    }

    fun send(event: Event) {
        runCatching { TelemetryDeck.signal("Usage.${event.name}") }
    }

    fun signal(name: String, parameters: Map<String, String> = emptyMap()) {
        runCatching { TelemetryDeck.signal(name, parameters) }
    }
}
