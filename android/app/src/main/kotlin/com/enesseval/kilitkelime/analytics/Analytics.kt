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
        wallpaperOn, notificationOn, tileAdded,
        // 1.1
        wordHunt, match, weeklySummary, shareCard, streakShown,
    }

    fun start(app: Application) {
        val builder = TelemetryDeck.Builder().appID(APP_ID).showDebugLogs(false)
        if (BuildConfig.DEBUG) builder.testMode(true)
        TelemetryDeck.start(app, builder)
    }

    fun send(event: Event) {
        runCatching { TelemetryDeck.signal("Usage.${event.name}") }
    }
}
