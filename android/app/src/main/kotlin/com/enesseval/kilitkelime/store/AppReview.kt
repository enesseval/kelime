package com.enesseval.kilitkelime.store

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.review.ReviewPrompt
import com.google.android.play.core.ktx.launchReview
import com.google.android.play.core.ktx.requestReview
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * "Uygulamayı değerlendir", "Arkadaşına öner" and the automatic rating request (docs/SYNC.md, 2026-11-18).
 * The request uses Play's In-App Review window; the store page is the fallback.
 */
object AppReview {
    const val PLAY_URL = "https://play.google.com/store/apps/details?id=com.enesseval.kilitkelime"
    const val SHARE_TEXT = "Kilit ekranında her gün İngilizce kelime öğreniyorum: Kilit Kelime. Ücretsiz indir: $PLAY_URL"

    /** The In-App Review window; false when Play could not offer it. */
    private suspend fun launchInApp(activity: Activity): Boolean = runCatching {
        val manager = ReviewManagerFactory.create(activity)
        val info = manager.requestReview()
        manager.launchReview(activity, info)
        true
    }.getOrDefault(false)

    fun openStorePage(context: Context) {
        runCatching {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.enesseval.kilitkelime")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.recoverCatching {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PLAY_URL)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** The profile row: no automatic request afterwards; the In-App window, else the store page. */
    suspend fun rateFromRow(app: KilitKelimeApp, activity: Activity) {
        Analytics.signal(Analytics.Signal.REVIEW_OPENED)
        app.model.write("review-row") { db -> ReviewPrompt.markRowTapped(db) }
        if (!launchInApp(activity)) openStorePage(activity)
    }

    fun shareApp(context: Context) {
        Analytics.signal(Analytics.Signal.SHARE_APP)
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, SHARE_TEXT)
        context.startActivity(Intent.createChooser(send, "Arkadaşına öner").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /**
     * Called when a round, a game or the daily puzzle ends well ([correct] of [total]). When the rule allows
     * (ReviewPrompt), the system window comes about a second later; the rule's own count is only spent then.
     */
    fun afterGoodMoment(app: KilitKelimeApp, activity: Activity, correct: Int, total: Int) {
        app.model.scope.launch {
            val today = app.model.clock.today
            val worth = app.model.read { db ->
                ReviewPrompt.shouldAsk(ReviewPrompt.studiedDays(db), correct, total, app.model.paywallShownThisSession, today, ReviewPrompt.state(db))
            }
            if (!worth) return@launch
            delay(1000)
            if (app.model.paywallShownThisSession) return@launch
            val ask = app.model.write("review-prompt") { db -> ReviewPrompt.take(db, correct, total, app.model.paywallShownThisSession, today) }
            if (!ask) return@launch
            Analytics.signal(Analytics.Signal.REVIEW_PROMPTED)
            launchInApp(activity)
        }
    }
}
