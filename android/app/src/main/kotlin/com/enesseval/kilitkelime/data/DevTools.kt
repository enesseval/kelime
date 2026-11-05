package com.enesseval.kilitkelime.data

import android.content.Context
import com.enesseval.kilitkelime.BuildConfig
import com.enesseval.kilitkelime.KilitKelimeApp

/**
 * Developer switches for debug builds (port of `DevTools.swift`). Never available in release
 * builds: `BuildConfig.DEV_TOOLS` is false there, like the iOS App Store build.
 */
object DevTools {
    val isAvailable: Boolean get() = BuildConfig.DEV_TOOLS

    private const val FORCE_PRO = "dev.forcePro"
    private val prefs get() = KilitKelimeApp.instance.getSharedPreferences("dev", Context.MODE_PRIVATE)

    /** Treat the user as Pro without a purchase. On by default wherever dev tools exist. */
    var forcePro: Boolean
        get() = isAvailable && prefs.getBoolean(FORCE_PRO, true)
        set(value) { prefs.edit().putBoolean(FORCE_PRO, value).apply() }
}
