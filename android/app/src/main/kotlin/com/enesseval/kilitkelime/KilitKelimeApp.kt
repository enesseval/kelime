package com.enesseval.kilitkelime

import android.app.Application
import com.enesseval.kilitkelime.account.AccountManager
import com.enesseval.kilitkelime.analytics.Analytics
import com.enesseval.kilitkelime.data.AppModel
import com.enesseval.kilitkelime.lock.LockScreenUpdater
import com.enesseval.kilitkelime.notifications.Channels
import com.enesseval.kilitkelime.store.PurchaseManager
import kotlinx.coroutines.launch

/**
 * Holds the app's few long-lived objects (a hand-written container instead of Hilt; see
 * docs/ANDROID_NOTES.md). Widgets, workers and receivers run in this process and use the same
 * database connection.
 */
class KilitKelimeApp : Application() {
    lateinit var model: AppModel
        private set
    lateinit var lockScreen: LockScreenUpdater
        private set
    lateinit var purchases: PurchaseManager
        private set
    lateinit var account: AccountManager
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        model = AppModel(this)
        lockScreen = LockScreenUpdater(this, model)
        model.onDataChanged = { reason -> lockScreen.refresh(reason) }
        Channels.create(this)
        Analytics.start(this)
        purchases = PurchaseManager(this, model)
        account = AccountManager(this, model, purchases)
        model.scope.launch {
            model.open()
            lockScreen.refresh("launch")
            lockScreen.scheduleRotation()
            purchases.start()
            account.start()
            model.checkForContent()
        }
    }

    companion object {
        lateinit var instance: KilitKelimeApp
            private set
    }
}
