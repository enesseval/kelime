@preconcurrency import ActivityKit
import Foundation
import KelimeCore

/// The exam countdown Live Activity (docs/V1_2_PLAN.md §5). `sync` makes it match the switch,
/// Pro (the trial counts) and the exam plan, and runs after every change plus whenever the app
/// comes to the foreground: that updates "bugün N kelime" and, because a Live Activity lives only
/// 8 to 12 hours, ends and restarts one that is nearly out of time.
@MainActor
enum ExamLiveActivity {
    private static var watchers: [String: Task<Void, Never>] = [:]
    private static var syncing = false
    private static var again = false

    static func sync(_ database: AppDatabase) async {
        // A second call while one runs asks for one more pass instead of racing it.
        if syncing { again = true; return }
        syncing = true
        defer { syncing = false }
        repeat {
            again = false
            await run(database)
        } while again
    }

    private static func run(_ database: AppDatabase) async {
        let clock = AppClock.system
        let plan = try? await database.reader.read { db in try ExamCountdownLine.current(db: db, clock: clock) }
        let existing = Activity<ExamCountdownAttributes>.activities
        guard let plan else {
            for activity in existing { await end(activity) }
            startedKey = nil
            return
        }
        // It was running before and is gone well before its lifetime was up, while the app was
        // not there to see it: the learner swiped it away, so the switch goes off.
        if existing.isEmpty, let started = startedKey, ExamCountdownLifetime.dismissedByUser(startedAt: started, now: .now) {
            startedKey = nil
            try? await database.writer.write { db in try Settings.set(.examCountdownOn, false, in: db) }
            return
        }
        let state = ExamCountdownState(plan)
        // The count changes at midnight and on every answer; mark the content stale at the day's end.
        let stale = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        let content = ActivityContent(state: state, staleDate: stale)
        let now = Date.now
        if let current = existing.first(where: { !ExamCountdownLifetime.needsRestart(startedAt: $0.attributes.startedAt, now: now) }) {
            for other in existing where other.id != current.id { await end(other) }
            await current.update(content)
            watch(current, database: database)
            return
        }
        for activity in existing { await end(activity) }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let activity = try Activity.request(attributes: ExamCountdownAttributes(startedAt: now), content: content)
            startedKey = now
            watch(activity, database: database)
        } catch {
            // Not allowed in the background or too many activities: the next sync tries again.
        }
    }

    /// When the running activity was requested, kept across launches to tell a swipe from a timeout.
    private static var startedKey: Date? {
        get { UserDefaults.standard.object(forKey: "examActivityStartedAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "examActivityStartedAt") }
    }

    private static func end(_ activity: Activity<ExamCountdownAttributes>) async {
        watchers[activity.id]?.cancel()
        watchers[activity.id] = nil
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    /// A Live Activity that disappears long before its lifetime is up was swiped away: the switch
    /// goes off with it (Android: swiping the notification turns it off).
    private static func watch(_ activity: Activity<ExamCountdownAttributes>, database: AppDatabase) {
        guard watchers[activity.id] == nil else { return }
        let startedAt = activity.attributes.startedAt
        watchers[activity.id] = Task {
            for await state in activity.activityStateUpdates {
                guard state == .dismissed || state == .ended else { continue }
                watchers[activity.id] = nil
                startedKey = nil
                if ExamCountdownLifetime.dismissedByUser(startedAt: startedAt, now: .now) {
                    try? await database.writer.write { db in try Settings.set(.examCountdownOn, false, in: db) }
                }
                return
            }
        }
    }
}
