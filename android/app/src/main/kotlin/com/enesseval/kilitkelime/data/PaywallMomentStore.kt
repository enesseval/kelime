package com.enesseval.kilitkelime.data

import com.enesseval.kilitkelime.core.model.PaywallMoment
import com.enesseval.kilitkelime.core.model.PaywallTrigger

/** Device-side state for [PaywallMoment] (the rules live in `:core`), kept in [LockPrefs]. */
object PaywallMomentStore {
    suspend fun shouldOffer(model: AppModel, now: Long = System.currentTimeMillis()): Boolean {
        val p = model.prefs.current()
        if (p.paywallMomentCount >= PaywallMoment.MAX_OFFERS) return false
        val days = model.read { db -> PaywallMoment.studyDays(db) }
        return PaywallMoment.shouldOffer(days, p.paywallMomentCount, p.paywallMomentLast, p.paywallLast, now, model.isPro.value)
    }

    /** Called for every paywall; the offer's own count only moves for [PaywallTrigger.MOMENT]. */
    suspend fun noteShown(model: AppModel, trigger: PaywallTrigger, now: Long = System.currentTimeMillis()) {
        model.prefs.update {
            if (trigger == PaywallTrigger.MOMENT) it.copy(paywallMomentCount = it.paywallMomentCount + 1, paywallMomentLast = now, paywallLast = now)
            else it.copy(paywallLast = now)
        }
    }
}
