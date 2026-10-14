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
    let clock = AppClock.system

    var database: AppDatabase? {
        if case .ready(let db) = phase { db } else { nil }
    }

    /// Called when the app comes to the foreground.
    func becameActive() async {
        guard let database else { return }
        await WidgetRefresher.refresh(database)
        dataVersion += 1
    }

    func start() async {
        if case .ready = phase { return }
        phase = .launching(step: .openDatabase, progress: 0)
        let contentURL = Bundle.main.url(forResource: "cards", withExtension: "json", subdirectory: "Content")
        do {
            let db = try await AppBootstrap.run(contentURL: contentURL, progress: { step, progress in
                Task { @MainActor [weak self] in
                    guard let self, case .launching = self.phase else { return }
                    self.phase = .launching(step: step, progress: progress)
                }
            })
            showOnboarding = !((try? await db.reader.read { db in try Settings.bool(.onboardingDone, in: db) }) ?? false)
            phase = .ready(db)
            purchases.start(app: self)
            await applySpeechRate()
            await WidgetRefresher.refresh(db)
        } catch {
            phase = .failed(error)
        }
    }

    // MARK: - Reads

    func read<T: Sendable>(_ body: @escaping @Sendable (Database) throws -> T) async -> T? {
        guard let database else { return nil }
        return try? await database.reader.read(body)
    }

    /// Starts a Quick Review, or shows the paywall when today's free session is used.
    func startQuickReview() async {
        let clock = clock
        let remaining = await read { db in try QuickReviewLimit.remaining(db: db, clock: clock) } ?? nil
        router.startQuickReview(remaining: remaining)
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

    func setDeck(_ deck: DeckID, enabled: Bool) async {
        await write(rebuildQueue: true) { db in
            try DeckQueries.setEnabled(enabled, deck: deck, db: db)
        }
    }

    func completeOnboarding(_ choices: OnboardingChoices) async {
        await write(rebuildQueue: true) { db in try choices.save(db: db) }
        if let minutes = choices.reminderMinutes { await Reminder.schedule(minutes: minutes) }
        showOnboarding = false
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
