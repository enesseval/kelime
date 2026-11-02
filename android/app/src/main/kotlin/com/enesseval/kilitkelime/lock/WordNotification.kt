package com.enesseval.kilitkelime.lock

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.ForegroundInfo
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.R
import com.enesseval.kilitkelime.core.widgets.WidgetActions
import com.enesseval.kilitkelime.core.widgets.WidgetSnapshot
import com.enesseval.kilitkelime.notifications.Channels
import kotlinx.coroutines.launch

/**
 * "Kilit ekranında bildirim olarak göster": a silent, low-importance ongoing notification with
 * the word and its meaning, updated every slot. Off by default.
 */
object WordNotification {
    private const val ID = 7

    fun canPost(context: Context) = NotificationManagerCompat.from(context).areNotificationsEnabled()

    fun show(context: Context, snapshot: WidgetSnapshot) {
        val card = snapshot.card ?: return
        if (!canPost(context)) return
        val open = PendingIntent.getActivity(
            context, 10,
            Intent(Intent.ACTION_VIEW, Uri.parse("kelime://word/${card.id}?src=notification"), context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        fun action(kind: String, request: Int) = PendingIntent.getBroadcast(
            context, request,
            Intent(context, NotificationActionReceiver::class.java).putExtra("kind", kind).putExtra("card", card.id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, Channels.WORD)
            .setSmallIcon(R.drawable.ic_tile)
            .setContentTitle(card.word)
            .setContentText("${card.pos.label} · ${card.meaning}")
            .setStyle(NotificationCompat.BigTextStyle().bigText("${card.pos.label} · ${card.meaning}\n${card.exampleEN}"))
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setContentIntent(open)
            .addAction(0, "Biliyorum", action("known", 11))
            .addAction(0, "Zorlanıyorum", action("struggling", 12))
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(ID, notification) }
    }

    fun cancel(context: Context) = NotificationManagerCompat.from(context).cancel(ID)

    /** Needed by expedited work on Android 11 and lower; never shown on newer versions. */
    fun workerForegroundInfo(context: Context): ForegroundInfo {
        val notification = NotificationCompat.Builder(context, Channels.WORD)
            .setSmallIcon(R.drawable.ic_tile)
            .setContentTitle(context.getString(R.string.app_name))
            .setSilent(true)
            .build()
        return ForegroundInfo(8, notification)
    }
}

/** Biliyorum / Zorlanıyorum from the notification. */
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val cardID = intent.getStringExtra("card") ?: return
        val kind = intent.getStringExtra("kind") ?: return
        val app = context.applicationContext as KilitKelimeApp
        val pending = goAsync()
        app.model.scope.launch {
            try {
                app.model.write("notification-$kind") { db ->
                    if (kind == "known") WidgetActions.markKnown(cardID, db, app.model.clock)
                    else WidgetActions.markStruggling(cardID, db, app.model.clock)
                }
            } finally {
                pending.finish()
            }
        }
    }
}
