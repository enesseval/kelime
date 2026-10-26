import Foundation
import KelimeCore
import Observation

/// App-wide state. Owns startup: the database opens and content imports off the main actor,
/// while the launch screen shows progress. A failure surfaces the step name instead of freezing.
@MainActor
@Observable
final class AppModel {
    enum Phase {
        case launching(step: StartupStep, progress: Double)
        case failed(StartupError)
        case ready(AppDatabase)
    }

    private(set) var phase: Phase = .launching(step: .openDatabase, progress: 0)

    /// Bumped after every write, so screens reload what they show.
    private(set) var dataVersion = 0
    /// True until the user finishes onboarding.
    private(set) var showOnboarding = false

    let router = AppRouter()
    let purchases = PurchaseManager()
    let account = AccountManager()
    let clock = AppClock.system

    var database: AppDatabase? {
        if case .ready(let db) = phase { db } else { nil }
    }

    /// Called when the app comes to the foreground.
    func becameActive() async {
        guard let database else { return }
        await purchases.refreshEntitlement()
        await WidgetRefresher.refresh(database)
        dataVersion += 1
        await account.sync()
        await updateContent()
    }

    /// The account sync changed lists: screens and the widget pick them up.
    func reloadAfterSync() async {
        guard let database else { return }
        dataVersion += 1
        await WidgetRefresher.rebuild(database)
    }

    func start() async {
        if case .ready = phase { return }
        phase = .launching(step: .openDatabase, progress: 0)
        let contentURL = Bundle.main.url(forResource: "cards", withExtension: "json", subdirectory: "Content")
        do {
            let downloaded = (try? AppConfig.sharedContainerURL()).map(ContentUpdater.downloadedURL(in:))
            let db = try await AppBootstrap.run(contentURL: contentURL, downloadedURL: downloaded, progress: { step, progress in
                Task { @MainActor [weak self] in
                    guard let self, case .launching = self.phase else { return }
                    self.phase = .launching(step: step, progress: progress)
                }
            })
            // An update that changes the content model starts everyone over once.
            _ = try? await db.writer.write { db in try ProgressReset.resetIfNeeded(db: db) }
            showOnboarding = !((try? await db.reader.read { db in try Settings.bool(.onboardingDone, in: db) }) ?? false)
            phase = .ready(db)
            purchases.start(app: self)
            account.start(app: self)
            #if DEBUG
            // Screenshots of the paywall: launch with `-showPaywall lists` (Debug only).
            if let name = UserDefaults.standard.string(forKey: "showPaywall"), let trigger = PaywallTrigger(rawValue: name) {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    router.showPaywall(trigger)
                }
            }
            #endif
            PhoneWatchSync.shared.start(database: db)
            await applySpeechRate()
            await WidgetRefresher.refresh(db)
            // The refresh may have moved the learner to the next unit.
            dataVersion += 1
            await updateContent()
        } catch {
            phase = .failed(error)
        }
    }

    /// Fetches newer content from GitHub Pages in the background. Offline or on any failure the
    /// app keeps what it has.
    func updateContent() async {
        guard let database, let directory = try? AppConfig.sharedContainerURL() else { return }
        guard case .updated = try? await ContentUpdater.update(database: database, directory: directory) else { return }
        await WidgetRefresher.rebuild(database)
        dataVersion += 1
    }

    // MARK: - Reads

    func read<T: Sendable>(_ body: @escaping @Sendable (Database) throws -> T) async -> T? {
        guard let database else { return nil }
        return try? await database.reader.read(body)
    }

    /// Starts a Quick Review, or shows the paywall when today's free session is used.
    func startQuickReview() async {
        router.startQuickReview()
    }

    // MARK: - Writes (each one refreshes widgets)

    func record(_ event: LearningEvent, cardID: String, source: ReviewSource) async {
        let clock = clock
        await write(rebuildQueue: false) { db in
            try LearningStore.record(event, cardID: cardID, source: source, clock: clock, db: db)
        }
    }

    /// Records a Quick Review answer and returns the card's state before and after it.
    func answerReview(cardID: String, correct: Bool, sessionID: String) async -> (before: LearningState, after: LearningState)? {
        guard let database else { return nil }
        let clock = clock
        let result = try? await database.writer.write { db in
            let before = try LearningStore.state(of: cardID, db: db).state
            let after = try LearningStore.record(.answered(correct: correct), cardID: cardID, source: .quickReview, clock: clock, sessionID: sessionID, db: db).state
            return (before, after)
        }
        guard let result else { return nil }
        dataVersion += 1
        await WidgetRefresher.refresh(database)
        return result
    }

    func setFavorite(_ favorite: Bool, cardID: String) async {
        await write(rebuildQueue: false) { db in
            try LearningStore.setFavorite(favorite, cardID: cardID, db: db)
        }
    }

    /// Kelimelerim › Listeler › kurs: the whole course on or off for the widget.
    func setCourse(enabled: Bool) async {
        await write(rebuildQueue: true) { db in try DeckQueries.setCourse(enabled, db: db) }
    }

    func setDeck(_ deck: DeckID, enabled: Bool) async {
        await write(rebuildQueue: true) { db in
            try DeckQueries.setEnabled(enabled, deck: deck, db: db)
        }
    }

    // MARK: - Own lists

    /// Pro, as the purchase manager knows it (false while Pro is not on sale).
    var isPro: Bool { purchases.isPro }

    /// Creates a list; free users with a list of their own get the paywall instead.
    func createList(title: String) async -> UserList? {
        guard let database else { return nil }
        let pro = isPro
        do {
            let list = try await database.writer.write { db in try UserLists.create(title: title, isPro: pro, db: db) }
            dataVersion += 1
            UsageCounter.count(.listCreated)
            Task { await account.sync() }
            return list
        } catch UserListError.limitReached {
            router.showPaywall(.lists)
        } catch {}
        return nil
    }

    /// Runs a list change; the widget rebuilds because its pool may have changed.
    func editList(_ body: @escaping @Sendable (Database) throws -> Void) async throws {
        guard let database else { return }
        try await database.writer.write(body)
        dataVersion += 1
        await WidgetRefresher.rebuild(database)
        Task { await account.sync() }
    }

    /// Saves a Keşfet or link list as the learner's; returns its local id.
    func importShared(_ shared: SharedList, sourceID: String) async -> String? {
        guard let database else { return nil }
        guard let id = try? await database.writer.write({ db in try UserLists.import(shared, sourceID: sourceID, db: db).id }) else { return nil }
        dataVersion += 1
        await WidgetRefresher.rebuild(database)
        UsageCounter.count(.listImported)
        return id
    }

    /// Writes the list to a temporary `.kelimelist` file to share.
    func exportList(_ id: String) async -> URL? {
        guard let shared = await read({ db in try UserLists.export(id, db: db) }) ?? nil,
              let data = try? shared.encoded() else { return nil }
        let name = shared.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).\(SharedList.fileExtension)")
        do {
            try data.write(to: url, options: .atomic)
            UsageCounter.count(.listShared)
            return url
        } catch {
            return nil
        }
    }

    /// Opens a shared `.kelimelist` file: the list is added and Listeler opens. Returns a message.
    func importList(from url: URL) async -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let shared = try? SharedList.decode(data) else {
            return "Bu dosya bir kelime listesi değil"
        }
        do {
            try await editList { db in try UserLists.import(shared, db: db) }
        } catch {
            return "Liste eklenemedi"
        }
        router.openLists()
        UsageCounter.count(.listImported)
        return "\(shared.title) eklendi · \(shared.cards.count) kelime"
    }

    func completeOnboarding(_ choices: OnboardingChoices) async {
        guard let database else { return }
        try? await database.writer.write { db in try choices.save(db: db) }
        // The level may have changed: the word on the widget now must come from the new course too.
        await WidgetRefresher.rebuild(database, includingCurrent: true)
        dataVersion += 1
        UsageCounter.count(.onboardingDone)
        if let minutes = choices.reminderMinutes { await Reminder.schedule(minutes: minutes) }
        showOnboarding = false
    }

    /// Logs a widget tap (`kelime://word/<id>?src=…&slot=…`) for Geliştirici › Widget günlüğü.
    func logWidgetOpen(_ url: URL) async {
        guard url.scheme == "kelime", url.host() == "word" else { return }
        let id = url.lastPathComponent
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let source = items.first { $0.name == "src" }?.value ?? "eski link"
        let slot = items.first { $0.name == "slot" }?.value.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
        let clock = clock
        // Written directly: a tap must not reload the widget, or the log would record our own reload.
        try? await database?.writer.write { db in
            try WidgetLog.recordTap(source: source, cardID: id, slot: slot, db: db, clock: clock)
        }
    }

    /// Ayarlar › Seviye: the widget, Quick Review, puzzle and current unit all move to `level`.
    func changeLevel(to level: CEFRLevel) async {
        guard let database else { return }
        try? await database.writer.write { db in try Curriculum.switchLevel(to: level, db: db) }
        await WidgetRefresher.rebuild(database, includingCurrent: true)
        dataVersion += 1
    }

    /// Ayarlar › İlerlemeyi sıfırla: forgets progress and choices, then shows onboarding.
    func resetProgress() async {
        Reminder.cancel()
        await write(rebuildQueue: true) { db in try ProgressReset.reset(db: db) }
        router.tab = .today
        showOnboarding = true
    }

    /// Developer tool: shows onboarding again (choices are kept until it is completed).
    func restartOnboarding() async {
        await write(rebuildQueue: false) { db in try Settings.set(.onboardingDone, false, in: db) }
        showOnboarding = true
    }

    /// Updates preferences that change the widget's card pool, rhythm, mode or theme.
    func updatePreferences(_ change: @escaping @Sendable (inout Preferences) -> Void) async {
        await write(rebuildQueue: true) { db in
            var prefs = try Preferences.load(db)
            change(&prefs)
            try prefs.save(db)
        }
    }

    func setSetting(_ key: SettingKey, _ value: String?) async {
        await write(rebuildQueue: false) { db in try Settings.set(key, value, in: db) }
        if key == .speechRate { await applySpeechRate() }
    }

    func applySpeechRate() async {
        let raw = await read { db in try Settings.string(.speechRate, in: db) } ?? nil
        Speaker.shared.rateMultiplier = raw.flatMap(Float.init) ?? 0.9
    }

    func dismissWidgetBanner() async {
        await write(rebuildQueue: false) { db in
            try Settings.set(.widgetBannerDismissed, true, in: db)
        }
    }

    /// Runs `body` in a write transaction, then reloads screens and widgets. Settings that change
    /// the card pool or slot grid pass `rebuildQueue` so upcoming widget slots are re-picked.
    func write(rebuildQueue: Bool, _ body: @escaping @Sendable (Database) throws -> Void) async {
        guard let database else { return }
        do {
            try await database.writer.write(body)
        } catch {
            return
        }
        dataVersion += 1
        if rebuildQueue {
            await WidgetRefresher.rebuild(database)
        } else {
            await WidgetRefresher.refresh(database)
        }
    }
}
