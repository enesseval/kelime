import Foundation
import GRDB

/// Gentle weekly tracking for Bugün and Kelimelerim. Missing a day shows nothing negative.
public struct WeekStats: Sendable, Equatable {
    /// Cards that became (or were confirmed) learned this week.
    public var learnedThisWeek: Int
    /// Cards currently struggling.
    public var strugglingNow: Int
    /// Monday…Sunday of the current week, with whether any answer was logged that day.
    public var days: [Day]

    public struct Day: Sendable, Equatable {
        public var date: LocalDate
        public var reviewed: Bool
        /// Turkish one-letter weekday: P S Ç P C C P.
        public var initial: String
    }
}

public enum StatsQueries {
    static let weekdayInitials = ["P", "S", "Ç", "P", "C", "C", "P"] // Pazartesi … Pazar

    /// Monday of the week containing `day`.
    public static func weekStart(for day: LocalDate) -> LocalDate {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        let weekday = utc.component(.weekday, from: date) // 1 = Sunday
        let offset = (weekday + 5) % 7 // days since Monday
        return day.adding(days: -offset)
    }

    public static func week(db: Database, clock: AppClock) throws -> WeekStats {
        let today = clock.today
        let start = weekStart(for: today)
        let end = start.adding(days: 6)
        let learned = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM card_state WHERE state = ? AND last_answered_on BETWEEN ? AND ?
            """, arguments: [LearningState.learned, start, end]) ?? 0
        let struggling = try CardState.filter(CardState.Columns.state == LearningState.struggling).fetchCount(db)
        let reviewedDays = try Set(LocalDate.fetchAll(db, sql: """
            SELECT DISTINCT answered_on FROM review_log WHERE answered_on BETWEEN ? AND ?
            """, arguments: [start, end]))
        let days = (0..<7).map { i -> WeekStats.Day in
            let d = start.adding(days: i)
            return WeekStats.Day(date: d, reviewed: reviewedDays.contains(d), initial: weekdayInitials[i])
        }
        return WeekStats(learnedThisWeek: learned, strugglingNow: struggling, days: days)
    }

    /// Days from today until `examDate`; nil when there is no date or it has passed.
    public static func daysUntilExam(_ examDate: LocalDate?, clock: AppClock) -> Int? {
        guard let examDate else { return nil }
        let days = examDate.days(since: clock.today)
        return days >= 0 ? days : nil
    }
}

/// The free Quick Review allowance: one session per local day; Pro is unlimited.
public enum QuickReviewLimit {
    public static let freeSessionsPerDay = 1

    /// Distinct Quick Review sessions with at least one answer today.
    public static func sessionsToday(db: Database, clock: AppClock) throws -> Int {
        try Int.fetchOne(db, sql: """
            SELECT COUNT(DISTINCT session_id) FROM review_log
            WHERE source = ? AND answered_on = ? AND session_id IS NOT NULL
            """, arguments: [ReviewSource.quickReview, clock.today]) ?? 0
    }

    /// Sessions left today, or nil for unlimited (Pro).
    public static func remaining(db: Database, clock: AppClock) throws -> Int? {
        if try Settings.bool(.isPro, in: db) { return nil }
        return max(freeSessionsPerDay - (try sessionsToday(db: db, clock: clock)), 0)
    }
}
