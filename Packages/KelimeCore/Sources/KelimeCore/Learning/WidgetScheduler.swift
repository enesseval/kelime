import Foundation

/// A card the widget may show, with just the fields selection needs.
public struct SchedulerCandidate: Sendable, Equatable {
    public var cardID: String
    public var state: LearningState
    public var lastShownAt: Date?
    /// A learned word whose review day has come (see `SpacedReview`).
    public var due: Bool

    public init(cardID: String, state: LearningState, lastShownAt: Date? = nil, due: Bool = false) {
        self.cardID = cardID
        self.state = state
        self.lastShownAt = lastShownAt
        self.due = due
    }
}

/// Pure selection logic for the widget rotation.
///
/// Weights: struggling 3, a learned word due for review 2, new 1, other learned words 0.2 but
/// only when last shown more than 14 days ago.
/// A card never repeats within the last 20 slots.
public enum WidgetScheduler {
    public static let recentWindow = 20
    public static let learnedCooldown: TimeInterval = 14 * 24 * 3600

    public static func weight(_ candidate: SchedulerCandidate, now: Date) -> Double {
        switch candidate.state {
        case .struggling:
            return 3
        case .new:
            return 1
        case .learned:
            if candidate.due { return 2 }
            guard let shown = candidate.lastShownAt else { return 0.2 }
            return now.timeIntervalSince(shown) > learnedCooldown ? 0.2 : 0
        }
    }

    /// Picks one card by weight, skipping `recent` (the most recent slots, newest first).
    ///
    /// If every weighted card is recent (a tiny pool), the least recently shown one is reused
    /// rather than leaving the slot empty. Returns nil only when nothing has weight.
    public static func pick(
        from candidates: [SchedulerCandidate],
        recent: [String],
        now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> String? {
        let window = Array(recent.prefix(recentWindow))
        let excluded = Set(window)
        let weighted = candidates.compactMap { c -> (String, Double)? in
            let w = weight(c, now: now)
            return w > 0 ? (c.cardID, w) : nil
        }
        let fresh = weighted.filter { !excluded.contains($0.0) }
        if let choice = weightedChoice(fresh, using: &rng) {
            return choice
        }
        // Everything with weight was shown recently: reuse the one shown longest ago.
        let available = Set(weighted.map(\.0))
        return window.reversed().first { available.contains($0) }
    }

    static func weightedChoice(_ items: [(String, Double)], using rng: inout some RandomNumberGenerator) -> String? {
        let total = items.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var target = Double.random(in: 0..<total, using: &rng)
        for (id, w) in items {
            if target < w { return id }
            target -= w
        }
        return items.last?.0
    }

    /// Start of the rotation slot containing `date`. Slots are aligned to the local day start,
    /// so a 3-hour rotation changes at 00:00, 03:00, 06:00… local time.
    public static func slotStart(containing date: Date, interval: RotationInterval, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let elapsed = date.timeIntervalSince(dayStart)
        let index = (elapsed / interval.seconds).rounded(.down)
        return dayStart.addingTimeInterval(index * interval.seconds)
    }

    /// Slot starts from the slot containing `now` through `now + horizon`.
    /// Slots restart at each local midnight, so a DST change only shifts that one day's slots.
    public static func slots(from now: Date, interval: RotationInterval, calendar: Calendar, horizon: TimeInterval = 24 * 3600) -> [Date] {
        let end = now.addingTimeInterval(horizon)
        var result: [Date] = []
        var cursor = slotStart(containing: now, interval: interval, calendar: calendar)
        while cursor <= end {
            result.append(cursor)
            var next = cursor.addingTimeInterval(interval.seconds)
            let nextDay = calendar.startOfDay(for: cursor).addingTimeInterval(36 * 3600)
            let midnight = calendar.startOfDay(for: nextDay)
            if next > midnight { next = midnight }
            cursor = next
        }
        return result
    }
}
