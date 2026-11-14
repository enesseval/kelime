package com.enesseval.kilitkelime.core

import com.enesseval.kilitkelime.core.model.PaywallSignals
import com.enesseval.kilitkelime.core.model.PaywallTrigger
import org.junit.Assert.assertEquals
import org.junit.Test

class PaywallSignalsTest {
    @Test fun everyTriggerSendsItsOwnNameAsSource() {
        val expected = listOf("moment", "archive", "personalPuzzle", "examPlan", "lists", "share", "discover", "rotation", "base", "trialEnded")
        assertEquals(expected.sorted(), PaywallTrigger.entries.map { PaywallSignals.shown(it).getValue("source") }.sorted())
        PaywallTrigger.entries.forEach { assertEquals(mapOf("source" to it.raw), PaywallSignals.shown(it)) }
    }

    @Test fun purchaseCarriesKindAndProduct() {
        assertEquals(mapOf("kind" to "trial", "product" to "pro.yearly"), PaywallSignals.purchase(true, "pro.yearly:p1y"))
        assertEquals(mapOf("kind" to "paid", "product" to "pro.lifetime"), PaywallSignals.purchase(false, "pro.lifetime"))
    }
}
