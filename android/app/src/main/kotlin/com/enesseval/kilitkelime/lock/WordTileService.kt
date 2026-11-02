package com.enesseval.kilitkelime.lock

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import kotlinx.coroutines.launch

/**
 * Quick Settings tile "Hızlı Tekrar" (docs/V1_1_PLAN.md §3): a tap opens a Quick Review round.
 * The subtitle shows the word on the lock screen now.
 */
class WordTileService : TileService() {
    override fun onStartListening() {
        val app = applicationContext as KilitKelimeApp
        app.model.scope.launch {
            val card = runCatching {
                app.model.read { db -> WidgetQueue.current(db, app.model.clock)?.let { CardQueries.card(it.cardID, db) } }
            }.getOrNull()
            val tile = qsTile ?: return@launch
            tile.label = "Hızlı Tekrar"
            if (Build.VERSION.SDK_INT >= 29) tile.subtitle = card?.word ?: "10 kelime"
            tile.state = Tile.STATE_ACTIVE
            tile.updateTile()
        }
    }

    override fun onClick() {
        Analytics.signal(Analytics.Signal.TILE_QUICK_REVIEW)
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("kelime://review?src=tile"), this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 20, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
