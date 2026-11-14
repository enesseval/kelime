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
        let all = Activity<ExamCountdownAttributes>.activities
        // Ended and dismissed activities are gone for our purposes; only live ones count.
        let existing = all.filter { ExamCountdownLifetime.isCurrent(phase(of: $0)) }
        guard let plan else {
            currentID = nil
            for activity in existing { await end(activity) }
            return
        }
        // No live activity while the switch is on (swiped while the app was closed, ended by the
        // system, never started): it is simply started again below. Only a live `.dismissed`
        // seen by `watch` turns the switch off.
        let state = ExamCountdownState(plan)
        // The count changes at midnight and on every answer; mark the content stale at the day's end.
        let stale = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        let content = ActivityContent(state: state, staleDate: stale)
        let now = Date.now
        if let current = existing.first(where: { !ExamCountdownLifetime.needsRestart(startedAt: $0.attributes.startedAt, now: now) }) {
            currentID = current.id
            for other in existing where other.id != current.id { await end(other) }
            await current.update(content)
            watch(current, database: database)
            return
        }
        currentID = nil
        for activity in existing { await end(activity) }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let activity = try Activity.request(attributes: ExamCountdownAttributes(startedAt: now), content: content)
            currentID = activity.id
            watch(activity, database: database)
        } catch {
            // Not allowed in the background or too many activities: the next sync tries again.
        }
    }

    /// Called after a swipe turned the switch off, so Ayarlar and Bugün reload.
    static var onSwitchedOff: (() -> Void)?

    /// The activity the app treats as the running one; the watchers compare against it.
    private static var currentID: String?

    private static func phase(of activity: Activity<ExamCountdownAttributes>) -> ExamCountdownLifetime.Phase {
        switch activity.activityState {
        case .active: .active
        case .stale: .stale
        case .dismissed: .dismissed
        default: .ended
        }
    }

    private static func end(_ activity: Activity<ExamCountdownAttributes>) async {
        // Forget it first: the `.ended` and `.dismissed` this causes are not a swipe.
        if currentID == activity.id { currentID = nil }
        watchers[activity.id]?.cancel()
        watchers[activity.id] = nil
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    /// A live `.dismissed` of the current activity is a swipe: the switch goes off with it
    /// (Android: swiping the notification turns it off). Everything else is ignored.
    private static func watch(_ activity: Activity<ExamCountdownAttributes>, database: AppDatabase) {
        guard watchers[activity.id] == nil else { return }
        let id = activity.id
        watchers[id] = Task {
            var sawEnded = false
            for await state in activity.activityStateUpdates {
                if Task.isCancelled { return }
                if state == .ended { sawEnded = true; continue }
                guard ExamCountdownLifetime.isSwipe(phase: phase(of: activity, state), activityID: id, currentID: currentID, sawEnded: sawEnded) else {
                    if state == .dismissed { break }
                    continue
                }
                watchers[id] = nil
                currentID = nil
                try? await database.writer.write { db in try Settings.set(.examCountdownOn, false, in: db) }
                onSwitchedOff?()
                return
            }
            if watchers[id] != nil, !Task.isCancelled { watchers[id] = nil }
        }
    }

    private static func phase(of activity: Activity<ExamCountdownAttributes>, _ state: ActivityState) -> ExamCountdownLifetime.Phase {
        switch state {
        case .active: .active
        case .stale: .stale
        case .dismissed: .dismissed
        default: .ended
        }
    }
}
