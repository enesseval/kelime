import Foundation
import GRDB

/// The exam countdown line (docs/V1_2_PLAN.md §5): "YDS'ye 23 gün · bugün 12 kelime". iOS shows
/// it in a Live Activity (lock screen and Dynamic Island), Android in an ongoing notification.
/// The exam plan is Pro (the trial counts); the date comes from the exam plan. With no date, or
/// once the exam day has passed, there is no line. The text is shared with the widget extension.
public enum ExamCountdownLine {
    /// Whether the countdown may be on screen: Pro, and an exam date that is today or ahead.
    public static func available(isPro: Bool, plan: ExamPlanStatus?) -> Bool {
        isPro && (plan.map { $0.daysLeft >= 0 } ?? false)
    }

    /// Whether the Live Activity should be running: switched on, and available.
    public static func shouldRun(enabled: Bool, isPro: Bool, plan: ExamPlanStatus?) -> Bool {
        enabled && available(isPro: isPro, plan: plan)
    }

    /// "YDS'ye", "YÖKDİL'e", "IELTS'e": YDS is read "ye-de-es", so it takes -ye.
    public static func toExam(_ exam: DeckID) -> String {
        "\(exam.rawValue)\(exam == .yds ? "'ye" : "'e")"
    }

    /// The line, or nil when there is nothing to show.
    public static func text(isPro: Bool, plan: ExamPlanStatus?) -> String? {
        guard available(isPro: isPro, plan: plan), let plan else { return nil }
        return text(of: plan)
    }

    /// The line of a plan that is known to be showing.
    public static func text(of plan: ExamPlanStatus) -> String {
        text(exam: plan.exam, daysLeft: plan.daysLeft, remaining: plan.remaining, dailyTarget: plan.dailyTarget, doneToday: plan.doneToday)
    }

    public static func text(exam: DeckID, daysLeft: Int, remaining: Int, dailyTarget: Int, doneToday: Int) -> String {
        let head = daysLeft == 0 ? "\(exam.rawValue) bugün" : "\(toExam(exam)) \(daysLeft) gün"
        let tail: String
        if remaining == 0 {
            tail = "hepsini öğrendin"
        } else if doneToday >= dailyTarget {
            tail = "bugünkü hedef tamam"
        } else {
            tail = "bugün \(dailyTarget) kelime"
        }
        return "\(head) · \(tail)"
    }

    /// The plan the Live Activity should show now, or nil when it must not run: switched off, not
    /// Pro (a trial that ended without a purchase included), no exam date, or the exam day is over.
    public static func current(db: Database, clock: AppClock, now: Date = .now) throws -> ExamPlanStatus? {
        let enabled = try Settings.bool(.examCountdownOn, in: db)
        guard enabled, try ProEntitlement.isPro(db: db, now: now) else { return nil }
        let plan = try ExamPlan.status(db: db, clock: clock)
        return shouldRun(enabled: enabled, isPro: true, plan: plan) ? plan : nil
    }
}

/// What the Live Activity carries: numbers only, the line is worked out by `ExamCountdownLine`
/// in the widget extension so app and extension never disagree.
public struct ExamCountdownState: Codable, Hashable, Sendable {
    public var exam: DeckID
    public var daysLeft: Int
    public var remaining: Int
    public var dailyTarget: Int
    public var doneToday: Int

    public init(exam: DeckID, daysLeft: Int, remaining: Int, dailyTarget: Int, doneToday: Int) {
        self.exam = exam
        self.daysLeft = daysLeft
        self.remaining = remaining
        self.dailyTarget = dailyTarget
        self.doneToday = doneToday
    }

    public init(_ plan: ExamPlanStatus) {
        self.init(exam: plan.exam, daysLeft: plan.daysLeft, remaining: plan.remaining, dailyTarget: plan.dailyTarget, doneToday: plan.doneToday)
    }

    public var line: String {
        ExamCountdownLine.text(exam: exam, daysLeft: daysLeft, remaining: remaining, dailyTarget: dailyTarget, doneToday: doneToday)
    }
}

/// A Live Activity lives about 8 to 12 hours; past this age the app ends and restarts it.
public enum ExamCountdownLifetime {
    public static let restartAfter: TimeInterval = 7 * 3600

    public static func needsRestart(startedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(startedAt) >= restartAfter
    }

    /// What the app can tell about an activity (a mirror of ActivityKit's `ActivityState`).
    public enum Phase: Sendable { case active, stale, ended, dismissed }

    /// Only a live activity counts as the current one; ended and dismissed ones are ignored and a
    /// new one is requested when none is alive.
    public static func isCurrent(_ phase: Phase) -> Bool {
        phase == .active || phase == .stale
    }

    /// Whether a state update seen while the app runs means the learner swiped the activity away,
    /// so the switch goes off. Only `.dismissed` of the current activity counts. `.ended` never
    /// does (the app ends activities itself, and the system ends them at their lifetime), and a
    /// `.dismissed` that follows an `.ended` is the end being cleared away, not a swipe. A missing
    /// activity found at a later sync is never a swipe: it is simply restarted.
    public static func isSwipe(phase: Phase, activityID: String, currentID: String?, sawEnded: Bool) -> Bool {
        phase == .dismissed && !sawEnded && activityID == currentID
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

public struct ExamCountdownAttributes: ActivityAttributes {
    public typealias ContentState = ExamCountdownState
    public var startedAt: Date

    public init(startedAt: Date) { self.startedAt = startedAt }
}
#endif
