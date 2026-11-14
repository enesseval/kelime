package com.enesseval.kilitkelime.data

import android.content.Context
import com.enesseval.kilitkelime.core.content.ContentImporter
import com.enesseval.kilitkelime.core.content.ContentUpdater
import com.enesseval.kilitkelime.core.content.Curriculum
import com.enesseval.kilitkelime.core.crossword.CoursePuzzle
import com.enesseval.kilitkelime.core.dates.AppClock
import com.enesseval.kilitkelime.core.db.SqlDb
import com.enesseval.kilitkelime.core.learning.ProgressReset
import com.enesseval.kilitkelime.core.learning.SystemRandom
import com.enesseval.kilitkelime.core.learning.WidgetQueue
import com.enesseval.kilitkelime.core.model.FreeTrial
import com.enesseval.kilitkelime.core.model.ProEntitlement
import com.enesseval.kilitkelime.core.model.SettingKey
import com.enesseval.kilitkelime.core.model.Settings
import com.enesseval.kilitkelime.core.widgets.WidgetLog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/** Startup progress, shown by the launch screen (port of `StartupStep`). */
enum class StartupStep(val title: String) {
    OPEN_DATABASE("Veritabanı açılıyor"),
    READ_CONTENT("İçerik okunuyor"),
    IMPORT_CONTENT("Kelimeler yükleniyor"),
    READY(""),
}

/**
 * The app's shared state, like the iOS `AppModel`: the database, the clock, Pro, and a data
 * version that screens observe to reload after any change.
 */
class AppModel(private val context: Context) {
    val clock: AppClock = AppClock.system
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val prefs = LockPrefs(context)

    private var _db: SqlDb? = null
    val db: SqlDb get() = _db ?: error("database not open")
    val isOpen: Boolean get() = _db != null

    private val _startup = MutableStateFlow(StartupStep.OPEN_DATABASE to 0.0)
    val startup: StateFlow<Pair<StartupStep, Double>> = _startup.asStateFlow()

    private val _dataVersion = MutableStateFlow(0)
    /** Bumped after every write; screens reload when it changes. */
    val dataVersion: StateFlow<Int> = _dataVersion.asStateFlow()

    private val _isPro = MutableStateFlow(false)
    /** Pro for every rule: a purchase or the running free trial (docs/V1_2_PLAN.md §2). */
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    private val _purchased = MutableStateFlow(false)
    /** A store purchase only (the paywall closes on this, not on the trial). */
    val purchased: StateFlow<Boolean> = _purchased.asStateFlow()

    private val _trial = MutableStateFlow(FreeTrial.Status(false, false, 0))
    val trial: StateFlow<FreeTrial.Status> = _trial.asStateFlow()

    /** The trial just ended and its one-time summary has not been shown (MainScaffold opens it). */
    val trialSummaryPending = MutableStateFlow(false)
    private var trialTimer: kotlinx.coroutines.Job? = null

    private val _onboardingDone = MutableStateFlow<Boolean?>(null)
    val onboardingDone: StateFlow<Boolean?> = _onboardingDone.asStateFlow()

    private val openLock = Mutex()

    /** Hook set by the lock-screen layer: redraw wallpaper, widgets, notification. */
    var onDataChanged: (suspend (reason: String) -> Unit)? = null

    private val downloadedFile get() = File(context.filesDir, "downloaded-cards.json")

    /** Opens the database and imports content (bundled, or a newer verified download). */
    suspend fun open(): SqlDb = openLock.withLock {
        _db?.let { return it }
        withContext(Dispatchers.IO) {
            _startup.value = StartupStep.OPEN_DATABASE to 0.0
            val database = AndroidSqlDb.open(context.getDatabasePath(AndroidSqlDb.FILE_NAME))
            _startup.value = StartupStep.READ_CONTENT to 0.0
            val bundled = context.assets.open("content/cards.json").bufferedReader().use { it.readText() }
            val downloaded = downloadedFile.takeIf { it.exists() }?.readText()
            val text = ContentUpdater.newest(bundled, downloaded)
            ContentImporter.importIfNeeded(text, database) { _startup.value = StartupStep.IMPORT_CONTENT to it }
            database.transaction {
                ProgressReset.resetIfNeeded(database)
                Curriculum.advance(database)
                WidgetQueue.refill(database, clock, SystemRandom())
                CoursePuzzle.keepToday(clock, database)
            }
            // 1.2: IS_PRO now means purchase or trial. An install from before it holds the purchase there.
            if (Settings.string(database, SettingKey.PURCHASED) == null) {
                Settings.setBool(database, SettingKey.PURCHASED, Settings.bool(database, SettingKey.IS_PRO))
            }
            if (FreeTrial.startIfNeeded(database, clock.now.toEpochMilli())) {
                com.enesseval.kilitkelime.analytics.Analytics.signal(com.enesseval.kilitkelime.analytics.Analytics.Signal.TRIAL_STARTED)
            }
            _db = database
            _isPro.value = Settings.bool(database, SettingKey.IS_PRO)
            _onboardingDone.value = Settings.bool(database, SettingKey.ONBOARDING_DONE)
            _startup.value = StartupStep.READY to 1.0
            database
        }
    }

    suspend fun <T> read(block: (SqlDb) -> T): T = withContext(Dispatchers.IO) { block(open()) }

    /** Runs [block] in a transaction, then refreshes every lock-screen surface. */
    suspend fun <T> write(reason: String, block: (SqlDb) -> T): T {
        val result = withContext(Dispatchers.IO) {
            val db = open()
            db.transaction { block(db) }
        }
        changed(reason)
        return result
    }

    /** Settings that change which word shows: the queue is rebuilt from the current slot. */
    suspend fun <T> writeAndRequeue(reason: String, keepCurrent: Boolean = true, block: (SqlDb) -> T): T = write(reason) { db ->
        val result = block(db)
        if (keepCurrent) WidgetQueue.clearFuture(db, clock) else WidgetQueue.clearCurrentAndFuture(db, clock)
        Curriculum.advance(db)
        WidgetQueue.refill(db, clock, SystemRandom())
        result
    }

    suspend fun changed(reason: String) {
        _dataVersion.value += 1
        withContext(Dispatchers.IO) {
            _isPro.value = Settings.bool(db, SettingKey.IS_PRO)
            _onboardingDone.value = Settings.bool(db, SettingKey.ONBOARDING_DONE)
            runCatching { WidgetLog.recordAppReload(reason, db, clock) }
        }
        onDataChanged?.invoke(reason)
    }

    /** RevenueCat told us the entitlement; faster rotation needs a new slot grid. */
    suspend fun setPurchased(purchased: Boolean) {
        withContext(Dispatchers.IO) { Settings.setBool(open(), SettingKey.PURCHASED, purchased) }
        refreshPro()
    }

    /**
     * Pro = purchase or running trial. Called at launch, on resume, after a purchase and when the
     * trial's last second passes: updates the cache and the flows, sends `trial.ended` once and raises
     * the summary page when due.
     */
    suspend fun refreshPro() {
        val now = clock.now.toEpochMilli()
        val db = open()
        data class Snapshot(val purchased: Boolean, val status: FreeTrial.Status, val changed: Boolean, val ended: Boolean, val summary: Boolean)
        val snap = withContext(Dispatchers.IO) {
            db.transaction {
                val purchased = Settings.bool(db, SettingKey.PURCHASED)
                val status = FreeTrial.status(db, now)
                val changed = ProEntitlement.cache(purchased || status.active, db)
                Snapshot(purchased, status, changed, FreeTrial.takeEnded(db, now), FreeTrial.summaryDue(db, now))
            }
        }
        _purchased.value = snap.purchased
        _trial.value = snap.status
        _isPro.value = snap.purchased || snap.status.active
        if (snap.ended) com.enesseval.kilitkelime.analytics.Analytics.signal(com.enesseval.kilitkelime.analytics.Analytics.Signal.TRIAL_ENDED)
        if (snap.summary) trialSummaryPending.value = true
        scheduleTrialEnd(snap.status)
        if (snap.changed) writeAndRequeue("pro") {}
    }

    private fun scheduleTrialEnd(status: FreeTrial.Status) {
        trialTimer?.cancel()
        if (!status.active) return
        trialTimer = scope.launch {
            kotlinx.coroutines.delay(status.remainingMs + 1000)
            // refreshPro() schedules again and cancels the old timer: this one must not cancel itself.
            trialTimer = null
            refreshPro()
        }
    }

    /**
     * Runs [block] (which may count today for the streak and returns whether it did) and sends
     * `streak.day` once a day, with `source`, and `streak.freezeUsed` (docs/SYNC.md).
     */
    suspend fun studied(reason: String, source: com.enesseval.kilitkelime.core.games.StreakSource, block: (SqlDb) -> Boolean) {
        val pro = isPro.value
        val (newDay, newFreeze) = write(reason) { db ->
            // The streak only changes with the day's first study; later ones skip the reads.
            val studiedToday = db.query("SELECT 1 FROM streak_day WHERE day = ?", listOf(clock.today)) { true }.isNotEmpty()
            if (studiedToday) return@write block(db) to false
            val before = com.enesseval.kilitkelime.core.games.Streak.status(db, clock, pro).frozen
            val counted = block(db)
            val after = com.enesseval.kilitkelime.core.games.Streak.status(db, clock, pro).frozen
            counted to (after - before).isNotEmpty()
        }
        if (newDay) com.enesseval.kilitkelime.analytics.Analytics.signal(com.enesseval.kilitkelime.analytics.Analytics.Signal.STREAK_DAY, mapOf("source" to source.raw))
        if (newFreeze) com.enesseval.kilitkelime.analytics.Analytics.signal(com.enesseval.kilitkelime.analytics.Analytics.Signal.STREAK_FREEZE_USED)
        // A good moment: ask for the daily reminder (or offer Pro) once the round's screen closes.
        // Only while a round is open, so a late write can't surface in an unrelated later round.
        if (!roundOpen.value) return
        if (!reminderAskPending.value && com.enesseval.kilitkelime.notifications.ReminderAsk.shouldAsk(context, this)) {
            reminderAskPending.value = true
        } else if (!reminderAskPending.value && !isPro.value && !paywallMomentPending.value && PaywallMomentStore.shouldOffer(this)) {
            paywallMomentPending.value = true
        }
    }

    /** Set after a good moment once the learner has studied on enough days; Pro is offered when the round closes. */
    val paywallMomentPending = MutableStateFlow(false)

    /** True while a full-screen round (review, puzzle, game) is on screen; set by MainScaffold. */
    val roundOpen = MutableStateFlow(false)

    /** Set after a good moment when the reminder card may be shown; MainScaffold shows it after the round closes. */
    val reminderAskPending = MutableStateFlow(false)

    /** Checks GitHub Pages for newer content (at most every 6 hours). */
    fun checkForContent() {
        scope.launch(Dispatchers.IO) {
            runCatching {
                val outcome = ContentUpdater.update(open(), clock.now, ::download) { bytes -> downloadedFile.writeBytes(bytes) }
                if (outcome is ContentUpdater.Outcome.Updated) changed("content")
            }
        }
    }

    private fun download(url: String): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 20_000
        connection.readTimeout = 20_000
        connection.useCaches = false
        try {
            if (connection.responseCode != 200) throw ContentUpdater.UpdateException("badResponse")
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }
}
