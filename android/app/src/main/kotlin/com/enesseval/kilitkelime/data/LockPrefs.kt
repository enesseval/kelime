package com.enesseval.kilitkelime.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.store by preferencesDataStore("kelime")

/** Backgrounds for the lock-screen wallpaper word: six gradients/solids, or the user's photo. */
enum class WallpaperBackground(val raw: String, val title: String, val top: Long, val bottom: Long) {
    DUSK("dusk", "Alacakaranlık", 0xFF1B2942, 0xFF335AA6),
    PAPER("paper", "Kâğıt", 0xFFF4F1EB, 0xFFEAE6DE),
    INK("ink", "Mürekkep", 0xFF121110, 0xFF2A2825),
    EMBER("ember", "Kor", 0xFF442A08, 0xFFE49839),
    SAGE("sage", "Adaçayı", 0xFF1A3123, 0xFF50986B),
    MIST("mist", "Sis", 0xFFE2ECFD, 0xFFFBF9F5),
    PHOTO("photo", "Fotoğrafım", 0xFF000000, 0xFF000000);

    companion object {
        fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } ?: DUSK
    }
}

/** Device-only choices for the Android lock-screen surfaces. Learning settings live in the database. */
data class LockSettings(
    val wallpaperEnabled: Boolean = false,
    val background: WallpaperBackground = WallpaperBackground.DUSK,
    /** 0 = top, 0.5 = middle, 1 = bottom of the screen; the card's centre. */
    val position: Float = 0.72f,
    val notificationEnabled: Boolean = false,
    val onboardingLockAsked: Boolean = false,
    /** Cache key of the wallpaper last set ("slot|card|style|bg|pos"), so a slot is drawn once. */
    val lastWallpaperKey: String = "",
    val lastWeeklySummary: String = "",
    val lastReviewPrompt: Long = 0,
    /** Times the "Güzel bir tur oldu" reminder card was shown, and when last (epoch ms). */
    val reminderAskCount: Int = 0,
    val reminderAskLast: Long = 0,
    /** True once the app has opened the POST_NOTIFICATIONS system prompt (Android 13+). */
    val notificationsRequested: Boolean = false,
    /** Times the unprompted Pro offer (`PaywallTrigger.MOMENT`) opened, when last, and when any paywall last opened (epoch ms). */
    val paywallMomentCount: Int = 0,
    val paywallMomentLast: Long = 0,
    val paywallLast: Long = 0,
)

class LockPrefs(private val context: Context) {
    private object K {
        val wallpaper = booleanPreferencesKey("wallpaper_enabled")
        val background = stringPreferencesKey("wallpaper_background")
        val position = floatPreferencesKey("wallpaper_position")
        val notification = booleanPreferencesKey("notification_enabled")
        val asked = booleanPreferencesKey("onboarding_lock_asked")
        val lastKey = stringPreferencesKey("wallpaper_last_key")
        val weekly = stringPreferencesKey("weekly_summary_seen")
        val reviewPrompt = longPreferencesKey("review_prompt_at")
        val askCount = intPreferencesKey("reminder_ask_count")
        val askLast = longPreferencesKey("reminder_ask_last")
        val requested = booleanPreferencesKey("notifications_requested")
        val momentCount = intPreferencesKey("paywall_moment_count")
        val momentLast = longPreferencesKey("paywall_moment_last")
        val paywallLast = longPreferencesKey("paywall_last")
    }

    val flow: Flow<LockSettings> = context.store.data.map(::read)

    suspend fun current(): LockSettings = flow.first()

    private fun read(p: Preferences) = LockSettings(
        wallpaperEnabled = p[K.wallpaper] ?: false,
        background = WallpaperBackground.fromRaw(p[K.background]),
        position = p[K.position] ?: 0.72f,
        notificationEnabled = p[K.notification] ?: false,
        onboardingLockAsked = p[K.asked] ?: false,
        lastWallpaperKey = p[K.lastKey] ?: "",
        lastWeeklySummary = p[K.weekly] ?: "",
        lastReviewPrompt = p[K.reviewPrompt] ?: 0,
        reminderAskCount = p[K.askCount] ?: 0,
        reminderAskLast = p[K.askLast] ?: 0,
        notificationsRequested = p[K.requested] ?: false,
        paywallMomentCount = p[K.momentCount] ?: 0,
        paywallMomentLast = p[K.momentLast] ?: 0,
        paywallLast = p[K.paywallLast] ?: 0,
    )

    suspend fun update(change: (LockSettings) -> LockSettings) {
        context.store.edit { p ->
            val next = change(read(p))
            p[K.wallpaper] = next.wallpaperEnabled
            p[K.background] = next.background.raw
            p[K.position] = next.position
            p[K.notification] = next.notificationEnabled
            p[K.asked] = next.onboardingLockAsked
            p[K.lastKey] = next.lastWallpaperKey
            p[K.weekly] = next.lastWeeklySummary
            p[K.reviewPrompt] = next.lastReviewPrompt
            p[K.askCount] = next.reminderAskCount
            p[K.askLast] = next.reminderAskLast
            p[K.requested] = next.notificationsRequested
            p[K.momentCount] = next.paywallMomentCount
            p[K.momentLast] = next.paywallMomentLast
            p[K.paywallLast] = next.paywallLast
        }
    }
}
