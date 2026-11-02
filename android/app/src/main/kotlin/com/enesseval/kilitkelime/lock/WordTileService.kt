package com.enesseval.kilitkelime.lock

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.enesseval.kilitkelime.KilitKelimeApp
import com.enesseval.kilitkelime.MainActivity
import com.enesseval.kilitkelime.core.learning.CardQueries
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import kotlinx.coroutines.launch

/** Quick Settings tile: the current word as its subtitle; a tap opens the word. */
class WordTileService : TileService() {
    private var cardID: String? = null

    override fun onStartListening() {
        val app = applicationContext as KilitKelimeApp
        app.model.scope.launch {
            val card = runCatching {
                app.model.read { db -> WidgetQueue.current(db, app.model.clock)?.let { CardQueries.card(it.cardID, db) } }
            }.getOrNull()
            cardID = card?.id
            val tile = qsTile ?: return@launch
            tile.label = card?.word ?: "Kilit Kelime"
            if (Build.VERSION.SDK_INT >= 29) tile.subtitle = card?.primaryMeaning ?: ""
            tile.state = Tile.STATE_ACTIVE
            tile.updateTile()
        }
    }

    override fun onClick() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("kelime://word/${cardID ?: ""}?src=tile"), this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 20, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
