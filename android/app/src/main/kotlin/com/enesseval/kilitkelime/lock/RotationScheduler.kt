package com.enesseval.kilitkelime.lock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.enesseval.kilitkelime.KilitKelimeApp
import java.time.Duration
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Rotation on Android: a 15-minute periodic job as the safety net (WorkManager's minimum), plus
 * a one-time job at the next slot boundary. When the user allows exact alarms, an exact alarm
 * fires at the boundary too; otherwise the change may drift (Doze), and WidgetLog records how much.
 */
object RotationScheduler {
    private const val PERIODIC = "rotation-periodic"
    private const val SLOT = "rotation-slot"

    fun schedulePeriodic(context: Context) {
        val request = PeriodicWorkRequestBuilder<RotationWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun scheduleNext(context: Context, at: Instant) {
        val delay = Duration.between(Instant.now(), at).plusSeconds(1).coerceAtLeast(Duration.ofSeconds(5))
        val request = OneTimeWorkRequestBuilder<RotationWorker>().setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS).build()
        WorkManager.getInstance(context).enqueueUniqueWork(SLOT, ExistingWorkPolicy.REPLACE, request)

        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 1, Intent(context, SlotAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (canScheduleExact(context)) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.toEpochMilli() + 500, pending)
        } else {
            alarms.cancel(pending)
        }
    }

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    /** Runs a refresh now, as expedited work (alarm, boot, time zone change). */
    fun runNow(context: Context) {
        val request = OneTimeWorkRequestBuilder<RotationWorker>()
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork("rotation-now", ExistingWorkPolicy.REPLACE, request)
    }
}

class RotationWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val app = applicationContext as KilitKelimeApp
        app.lockScreen.refresh("rotation")
        return Result.success()
    }

    override suspend fun getForegroundInfo() = WordNotification.workerForegroundInfo(applicationContext)
}

class SlotAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = RotationScheduler.runNow(context)
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        RotationScheduler.schedulePeriodic(context)
        RotationScheduler.runNow(context)
    }
}
