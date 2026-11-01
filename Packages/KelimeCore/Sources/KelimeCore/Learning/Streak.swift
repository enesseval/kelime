import Foundation
import GRDB

/// What counted a day for the streak.
public enum StreakSource: String, Sendable, CaseIterable {
    case quickReview
    case puzzle
    case wordSearch
    case match
}

/// The study streak: local days in a row on which the learner finished a Quick Review, solved
/// at least one crossword word or finished a game. Looking at the widget doesn't count.
///
/// A missed day is covered by a freeze, at most `freezes(isPro:)` per Monday–Sunday week, and
/// only a single missed day at a time: two empty days in a row end the streak.
public struct StreakStatus: Sendable, Equatable {
    /// Days in the streak, today included when today is studied.
    public var current: Int
    /// The longest streak ever reached.
    public var longest: Int
    /// Today has nothing yet but yesterday kept the streak alive: study today to keep it.
    public var atRisk: Bool
    public var studiedToday: Bool
    /// Missed days a freeze covered, inside the current streak.
    public var frozenDays: [LocalDate]
    /// Studied days among the last `calendarDays`, for the streak calendar.
    public var studiedDays: Set<LocalDate>
}

public enum Streak {
    /// Missed days a week can absorb without breaking the streak.
    public static func freezes(isPro: Bool) -> Int { isPro ? 2 : 1 }

    /// Days the streak calendar shows (five weeks).
    public static let calendarDays = 35

    /// Marks `day` as studied by `source`. Safe to call many times a day.
    public static func record(_ source: StreakSource, on day: LocalDate, db: Database) throws {
        let existing = try String.fetchOne(db, sql: "SELECT sources FROM streak_day WHERE day = ?", arguments: [day])
        var sources = Set((existing ?? "").split(separator: ",").map(String.init))
        guard sources.insert(source.rawValue).inserted || existing == nil else { return }
        try db.execute(
            sql: "INSERT INTO streak_day (day, sources) VALUES (?, ?) ON CONFLICT(day) DO UPDATE SET sources = excluded.sources",
            arguments: [day, sources.sorted().joined(separator: ",")]
        )
        let status = try self.status(db: db, today: day, isPro: true)
        if status.current > (try Settings.int(.longestStreak, in: db) ?? 0) {
            try Settings.set(.longestStreak, status.current, in: db)
        }
    }

    public static func status(db: Database, clock: AppClock) throws -> StreakStatus {
        try status(db: db, today: clock.today, isPro: try Settings.bool(.isPro, in: db))
    }

    static func status(db: Database, today: LocalDate, isPro: Bool) throws -> StreakStatus {
        let days = try Set(LocalDate.fetchAll(db, sql: "SELECT day FROM streak_day WHERE day >= ?", arguments: [today.adding(days: -800)]))
        var status = compute(days: days, today: today, freezesPerWeek: freezes(isPro: isPro))
        status.longest = max(status.current, try Settings.int(.longestStreak, in: db) ?? 0)
        return status
    }

    /// The streak rules on a set of studied days. Pure, for tests.
    public static func compute(days: Set<LocalDate>, today: LocalDate, freezesPerWeek: Int) -> StreakStatus {
        let studiedToday = days.contains(today)
        var count = 0
        var frozen: [LocalDate] = []
        var usedByWeek: [LocalDate: Int] = [:]
        // Today without study yet doesn't break anything; the streak is counted up to yesterday.
        var day = studiedToday ? today : today.adding(days: -1)
        while true {
            if days.contains(day) {
                count += 1
                day = day.adding(days: -1)
                continue
            }
            // A single missed day, with study before it and a freeze left in its week.
            let week = StatsQueries.weekStart(for: day)
            let earlier = day.adding(days: -1)
            if count > 0, days.contains(earlier), usedByWeek[week, default: 0] < freezesPerWeek {
                usedByWeek[week, default: 0] += 1
                frozen.append(day)
                day = earlier
                continue
            }
            break
        }
        let calendarStart = today.adding(days: -(calendarDays - 1))
        return StreakStatus(
            current: count,
            longest: count,
            atRisk: !studiedToday && count > 0,
            studiedToday: studiedToday,
            frozenDays: frozen,
            studiedDays: days.filter { $0 >= calendarStart }
        )
    }
}
