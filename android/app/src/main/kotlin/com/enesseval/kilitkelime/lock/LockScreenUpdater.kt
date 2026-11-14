package com.enesseval.kilitkelime.lock

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.TileService
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.crossword.CoursePuzzle
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.learning.WidgetScheduler
import com.enesseval.kilitkelime.core.model.Preferences
import com.enesseval.kilitkelime.core.model.WidgetMode
import com.enesseval.kilitkelime.core.widgets.WidgetLog
import com.enesseval.kilitkelime.core.widgets.WidgetSnapshot
import com.enesseval.kilitkelime.core.widgets.WidgetTimelineBuilder
import com.enesseval.kilitkelime.data.AppModel
import com.enesseval.kilitkelime.data.LockSettings
import com.enesseval.kilitkelime.widget.Widgets
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.Instant

/**
 * Keeps every "every glance" surface on the same word: the lock-screen wallpaper, the Glance
 * widgets, the silent notification and the Quick Settings tile. Runs after app changes and at
 * every rotation slot (RotationScheduler).
 */
class LockScreenUpdater(private val context: Context, private val model: AppModel) {
    private val mutex = Mutex()
    val renderer = WallpaperRenderer(context)

    /** Whether this device lets the app set a separate lock-screen wallpaper. */
    fun wallpaperSupported(): Boolean {
        val wm = WallpaperManager.getInstance(context)
        return wm.isWallpaperSupported && wm.isSetWallpaperAllowed
    }

    data class Current(val snapshot: WidgetSnapshot, val nextAt: Instant, val mode: WidgetMode)

    /** Tops up the queue and returns what should be on screen now. */
    suspend fun current(): Current = withContext(Dispatchers.IO) {
        val db = model.open()
        val clock = model.clock
        db.transaction {
            Curriculum.advance(db)
            WidgetQueue.refill(db, clock, SystemRandom())
            CoursePuzzle.keepToday(clock, db)
        }
        val prefs = Preferences.load(db)
        val snapshot = WidgetTimelineBuilder.current(db, clock, SystemRandom())
        var next = WidgetScheduler.nextSlot(clock.now, prefs.effectiveRotation, clock.zone)
        if (prefs.defaultWidgetMode == WidgetMode.SELF_TEST) {
            // The wallpaper flips between question and answer at the same moments as the widgets.
            val change = WidgetTimelineBuilder.nextSelfTestChange(snapshot.slotStart, prefs.effectiveRotation, clock.now)
            if (change != null && change < next) next = change
        }
        Current(snapshot, next, prefs.defaultWidgetMode)
    }

    suspend fun refresh(reason: String) = mutex.withLock {
        runCatching {
            val now = current()
            val settings = model.prefs.current()
            if (settings.wallpaperEnabled) applyWallpaper(now, settings, reason)
            if (settings.notificationEnabled) WordNotification.show(context, now.snapshot) else WordNotification.cancel(context)
            ExamNotification.sync(context, model, settings.examNotificationEnabled)
            Widgets.updateAll(context)
            if (Build.VERSION.SDK_INT >= 24) {
                runCatching { TileService.requestListeningState(context, ComponentName(context, WordTileService::class.java)) }
            }
            RotationScheduler.scheduleNext(context, now.nextAt)
        }
    }

    suspend fun scheduleRotation() = RotationScheduler.schedulePeriodic(context)

    /** Renders and sets the lock wallpaper when the word, style or background changed. */
    private suspend fun applyWallpaper(now: Current, settings: LockSettings, reason: String) = withContext(Dispatchers.Default) {
        val card = now.snapshot.card ?: return@withContext
        if (!wallpaperSupported()) return@withContext
        val key = listOf(now.snapshot.slotStart.toEpochMilli(), card.id, now.mode.raw, now.snapshot.phase.name, settings.background.raw, settings.position, photoStamp()).joinToString("|")
        if (key == settings.lastWallpaperKey) return@withContext
        val bitmap = renderer.render(
            WallpaperRenderer.Spec(card, now.snapshot.previousCard, now.mode, settings.background, settings.position, now.snapshot.phase),
        )
        try {
            // FLAG_LOCK only: the home-screen wallpaper stays untouched.
            WallpaperManager.getInstance(context).setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK)
            model.prefs.update { it.copy(lastWallpaperKey = key) }
            withContext(Dispatchers.IO) {
                WidgetLog.recordUpdate("wallpaper", card.id, now.snapshot.slotStart, now.nextAt, model.db, model.clock, reason)
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun photoStamp(): Long = renderer.photoFile.takeIf { it.exists() }?.lastModified() ?: 0

    /** Forces the wallpaper to redraw (style, background or photo changed). */
    suspend fun redrawWallpaper() {
        model.prefs.update { it.copy(lastWallpaperKey = "") }
        refresh("wallpaper-settings")
    }
}
