package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.db.SqlDb

/** Why the paywall opened. The headline adapts; the paywall never opens on first launch. */
enum class PaywallTrigger(val raw: String) {
    BASE("base"), LISTS("lists"), SHARE("share"), ROTATION("rotation"),
    PERSONAL_PUZZLE("personalPuzzle"), ARCHIVE("archive"), EXAM_PLAN("examPlan"), DISCOVER("discover");

    val headline: String
        get() = when (this) {
            BASE -> "Kilit Kelime Pro"
            LISTS -> "Sınırsız kendi listen"
            SHARE -> "Listeni paylaş"
            ROTATION -> "Daha sık yeni kelime"
            PERSONAL_PUZZLE -> "Sana özel bulmaca"
            ARCHIVE -> "Bulmaca arşivi"
            EXAM_PLAN -> "Sınav planı"
            DISCOVER -> "Keşfet'ten hazır listeler"
        }
}

/** Product ids and the cached Pro entitlement (RevenueCat entitlement "pro"). */
object ProEntitlement {
    const val ENTITLEMENT = "pro"
    const val LIFETIME_ID = "pro.lifetime"
    const val YEARLY_ID = "pro.yearly"
    const val MONTHLY_ID = "pro.monthly"
    val allProductIDs = listOf(LIFETIME_ID, YEARLY_ID, MONTHLY_ID)

    /** Pro when any active product is one of ours. Play ids may carry ":base-plan" suffixes. */
    fun isPro(activeProductIDs: Iterable<String>): Boolean =
        activeProductIDs.any { id -> allProductIDs.contains(id.substringBefore(':')) }

    /** Stores the entitlement; returns true when it changed (the widget queue then rebuilds). */
    fun cache(isPro: Boolean, db: SqlDb): Boolean {
        val old = Settings.bool(db, SettingKey.IS_PRO)
        if (old == isPro) return false
        Settings.setBool(db, SettingKey.IS_PRO, isPro)
        return true
    }
}
