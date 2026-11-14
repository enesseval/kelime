package com.enesseval.kilitkelime.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.games.Streak
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

object Channels {
    const val WORD = "word"
    const val REMINDER = "reminder"
    const val EXAM = "exam"

    fun create(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(WORD, context.getString(R.string.channel_word), NotificationManager.IMPORTANCE_LOW).apply {
                description = context.getString(R.string.channel_word_description)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(EXAM, context.getString(R.string.channel_exam), NotificationManager.IMPORTANCE_LOW).apply {
                description = context.getString(R.string.channel_exam_description)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(REMINDER, context.getString(R.string.channel_reminder), NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = context.getString(R.string.channel_reminder_description)
            },
        )
    }
}

/**
 * The daily reminder at the time chosen in onboarding or Ayarlar (port of `Reminder.swift`):
 * one notification a day, skipped when the learner already studied that day.
 */
object Reminder {
    private const val WORK = "reminder"

    fun schedule(context: Context, minutes: Int?) {
        val wm = WorkManager.getInstance(context)
        if (minutes == null) {
            wm.cancelUniqueWork(WORK)
            return
        }
        val now = LocalDateTime.now()
        var at = now.toLocalDate().atTime(minutes / 60, minutes % 60)
        if (!at.isAfter(now)) at = at.plusDays(1)
        val delay = Duration.between(now.atZone(ZoneId.systemDefault()), at.atZone(ZoneId.systemDefault()))
        val request = OneTimeWorkRequestBuilder<ReminderWorker>().setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS).build()
        wm.enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, request)
    }

    /** "20:30". */
    fun label(minutes: Int) = "%02d:%02d".format(minutes / 60, minutes % 60)
}

class ReminderWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val app = applicationContext as KilitKelimeApp
        val (minutes, streak) = app.model.read { db ->
            Settings.int(db, SettingKey.REMINDER_TIME) to Streak.status(db, app.model.clock, app.model.isPro.value)
        }
        if (!streak.studiedToday && NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()) {
            // A streak at risk changes the text (docs/V1_1_PLAN.md §1).
            val title = if (streak.atRisk) "Serin bu akşam bitiyor" else "Tekrar zamanı"
            val text = if (streak.atRisk) "${streak.current} günlük serin bu akşam bitiyor. 2 dakikalık bir tur yeter."
            else "Günde bir hatırlatma: 2 dakikalık bir Hızlı Tekrar seni bekliyor."
            val open = PendingIntent.getActivity(
                applicationContext, 30,
                Intent(Intent.ACTION_VIEW, Uri.parse("kelime://review"), applicationContext, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val notification = NotificationCompat.Builder(applicationContext, Channels.REMINDER)
                .setSmallIcon(R.drawable.ic_tile)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            runCatching { NotificationManagerCompat.from(applicationContext).notify(9, notification) }
        }
        Reminder.schedule(applicationContext, minutes)
        return Result.success()
    }
}
