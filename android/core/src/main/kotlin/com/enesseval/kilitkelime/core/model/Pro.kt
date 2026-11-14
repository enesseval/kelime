package com.enesseval.kilitkelime.core.model

import com.enesseval.kilitkelime.core.db.SqlDb

/** Why the paywall opened. The headline adapts; the paywall never opens on first launch. */
enum class PaywallTrigger(val raw: String) {
    BASE("base"), LISTS("lists"), SHARE("share"), ROTATION("rotation"),
    PERSONAL_PUZZLE("personalPuzzle"), ARCHIVE("archive"), EXAM_PLAN("examPlan"), DISCOVER("discover"),
    /** Not a locked feature: offered once the learner has studied on a few days and liked it. */
    MOMENT("moment"),
    /** The one summary page when the 3-day free trial ends (docs/V1_2_PLAN.md §2). */
    TRIAL_ENDED("trialEnded");

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
            MOMENT -> "Güzel gidiyorsun"
            TRIAL_ENDED -> "Deneme bitti"
        }
}

/**
 * Product ids and the cached Pro entitlement. The RevenueCat entitlement's identifier is
 * `kelime_widget_pro` (project "Kelime Widget"); it carries purchases across iOS and Android.
 */
object ProEntitlement {
    const val ENTITLEMENT = "kelime_widget_pro"
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

/**
 * Pro is offered on its own only after the learner has come back: studied on a few different
 * days, at the end of a good round, never right after onboarding (port of `PaywallMoment.swift`).
 * Locked features still open the paywall when tapped; this is the one unprompted offer.
 */
object PaywallMoment {
    /** Different days with a finished round, solved crossword word or finished game. */
    const val STUDY_DAYS = 3
    /** At most this many offers, this far apart. */
    const val MAX_OFFERS = 2
    const val MS_BETWEEN = 14L * 24 * 3600 * 1000
    /** No offer within this long after any paywall (a locked feature the learner tapped). */
    const val QUIET_AFTER_PAYWALL_MS = 48L * 3600 * 1000

    /** Times are epoch ms; 0 = never. */
    fun shouldOffer(studyDays: Int, offers: Int, lastOffer: Long, lastPaywall: Long, now: Long, isPro: Boolean = false): Boolean {
        // Pro includes the running free trial: no unprompted paywall while it lasts (docs/V1_2_PLAN.md §2).
        if (isPro) return false
        if (studyDays < STUDY_DAYS || offers >= MAX_OFFERS) return false
        if (lastOffer > 0 && now - lastOffer < MS_BETWEEN) return false
        if (lastPaywall > 0 && now - lastPaywall < QUIET_AFTER_PAYWALL_MS) return false
        return true
    }

    /** Different days in `streak_day`. */
    fun studyDays(db: SqlDb): Int =
        db.query("SELECT COUNT(DISTINCT day) FROM streak_day") { it.longAt(0) ?: 0 }.firstOrNull()?.toInt() ?: 0
}

/** Telemetry parameters (docs/V1_2_PLAN.md §1); the values are the same strings on iOS and Android. */
object PaywallSignals {
    /** `Usage.paywallShown`: the trigger's name as is. */
    fun shown(trigger: PaywallTrigger): Map<String, String> = mapOf("source" to trigger.raw)

    /** `Usage.purchase`: `trial` when the store trial started, else `paid`; the product id without a Play base-plan suffix. */
    fun purchase(isTrial: Boolean, productId: String): Map<String, String> =
        mapOf("kind" to if (isTrial) "trial" else "paid", "product" to productId.substringBefore(':'))
}
