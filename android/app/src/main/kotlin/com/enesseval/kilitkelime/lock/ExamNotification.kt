package com.enesseval.kilitkelime.lock

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.core.model.ExamCountdownLine
import com.enesseval.kilitkelime.core.model.ExamPlan
import com.enesseval.kilitkelime.data.AppModel
import com.enesseval.kilitkelime.notifications.Channels

/**
 * Sınav geri sayımı (docs/V1_2_PLAN.md §5): "YDS'ye 23 gün · bugün 12 kelime" as a silent ongoing
 * notification on the lock screen. Dismissible: "Kapat" or a swipe turns it off. It needs Pro (the trial
 * counts), an exam date from the exam plan, and goes by itself once the exam day has passed.
 */
object ExamNotification {
    // 7 word, 8 worker, 9 daily reminder.
    private const val ID = 10
    const val OFF = "exam-off"

    /** Posts or removes the notification to match the setting, Pro and the exam plan. */
    suspend fun sync(context: Context, model: AppModel, enabled: Boolean) {
        val line = if (!enabled) null else {
            val plan = model.read { db -> ExamPlan.status(db, model.clock) }
            ExamCountdownLine.text(model.isPro.value, plan)
        }
        if (line == null || !WordNotification.canPost(context)) {
            cancel(context)
            return
        }
        show(context, line)
    }

    private fun show(context: Context, text: String) {
        val open = PendingIntent.getActivity(
            context, 20, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val off = PendingIntent.getBroadcast(
            context, 21, Intent(context, NotificationActionReceiver::class.java).putExtra("kind", OFF),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, Channels.EXAM)
            .setSmallIcon(R.drawable.ic_tile)
            .setContentTitle(text)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(open)
            .setDeleteIntent(off)
            .addAction(0, "Kapat", off)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(ID, notification)
        } catch (_: SecurityException) {
            // The permission was revoked between the check and the post.
        }
    }

    fun cancel(context: Context) = NotificationManagerCompat.from(context).cancel(ID)
}
