package com.enesseval.kilitkelime.store

import android.app.Activity
import android.content.Context
import com.enesseval.kilitkelime.BuildConfig
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.core.model.ProEntitlement
import com.enesseval.kilitkelime.data.AppModel
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitLogOut
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Pro through RevenueCat (port of `PurchaseManager.swift`): entitlement "pro", products
 * pro.monthly, pro.yearly (7-day trial) and pro.lifetime. The RevenueCat user id is the Supabase
 * user id when signed in, so a purchase on iOS unlocks Android and the other way round.
 */
class PurchaseManager(private val context: Context, private val model: AppModel) {
    enum class Result { PURCHASED, PENDING, CANCELLED }

    data class State(
        val packages: List<Package> = emptyList(),
        val loading: Boolean = false,
        val error: String? = null,
    ) {
        val monthly get() = packages.firstOrNull { it.packageType == PackageType.MONTHLY }
        val annual get() = packages.firstOrNull { it.packageType == PackageType.ANNUAL }
        val lifetime get() = packages.firstOrNull { it.packageType == PackageType.LIFETIME }

        /** How much cheaper a year is than twelve months, in percent. */
        val annualSaving: Int?
            get() {
                val m = monthly?.product?.price?.amountMicros ?: return null
                val a = annual?.product?.price?.amountMicros ?: return null
                val twelve = m * 12.0
                if (twelve <= 0) return null
                val saving = ((1 - a / twelve) * 100).toInt()
                return saving.takeIf { it > 0 }
            }
    }

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    val configured: Boolean get() = BuildConfig.REVENUECAT_KEY.isNotEmpty()

    fun start() {
        if (!configured) {
            model.scope.launch { refreshEntitlement() }
            return
        }
        if (!Purchases.isConfigured) {
            Purchases.logLevel = LogLevel.WARN
            Purchases.configure(PurchasesConfiguration.Builder(context, BuildConfig.REVENUECAT_KEY).build())
        }
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { info ->
            model.scope.launch { apply(info) }
        }
        model.scope.launch {
            runCatching { apply(Purchases.sharedInstance.awaitCustomerInfo()) }
            loadProducts()
        }
    }

    suspend fun loadProducts() {
        if (!configured || _state.value.packages.isNotEmpty() || _state.value.loading) return
        _state.value = _state.value.copy(loading = true, error = null)
        try {
            val order = listOf(PackageType.MONTHLY, PackageType.ANNUAL, PackageType.LIFETIME)
            val packages = Purchases.sharedInstance.awaitOfferings().current?.availablePackages.orEmpty()
                .sortedBy { order.indexOf(it.packageType).let { i -> if (i < 0) 9 else i } }
            _state.value = State(packages, false, if (packages.isEmpty()) "Ürünler yüklenemedi" else null)
        } catch (e: PurchasesException) {
            _state.value = State(emptyList(), false, "Ürünler yüklenemedi")
        }
    }

    suspend fun purchase(activity: Activity, pkg: Package): Result {
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            Analytics.send(Analytics.Event.purchase)
            Result.PURCHASED
        } catch (e: PurchasesTransactionException) {
            when {
                e.userCancelled -> Result.CANCELLED
                e.code == PurchasesErrorCode.PaymentPendingError -> Result.PENDING
                else -> {
                    _state.value = _state.value.copy(error = "Satın alma tamamlanamadı")
                    Result.CANCELLED
                }
            }
        }
    }

    /** "Satın alımları geri yükle". */
    suspend fun restore(): Boolean {
        if (!configured) return model.isPro.value
        try {
            apply(Purchases.sharedInstance.awaitRestore())
        } catch (e: PurchasesException) {
            _state.value = _state.value.copy(error = "Geri yükleme tamamlanamadı")
        }
        return model.isPro.value
    }

    suspend fun logIn(userID: String) {
        if (!configured) return
        runCatching { apply(Purchases.sharedInstance.awaitLogIn(userID).customerInfo) }
    }

    suspend fun logOut() {
        if (!configured) return
        runCatching { apply(Purchases.sharedInstance.awaitLogOut()) }
    }

    /** Reads the entitlement again. */
    suspend fun refreshEntitlement() {
        if (!configured) {
            model.setPro(false)
            return
        }
        runCatching { apply(Purchases.sharedInstance.awaitCustomerInfo()) }
    }

    /** The entitlement, or any of our products owned directly. */
    private suspend fun apply(info: CustomerInfo) {
        val products = info.activeSubscriptions + info.allPurchasedProductIds.filter { it.startsWith(ProEntitlement.LIFETIME_ID) }
        val active = info.entitlements[ProEntitlement.ENTITLEMENT]?.isActive == true || ProEntitlement.isPro(products)
        model.setPro(active)
    }
}
