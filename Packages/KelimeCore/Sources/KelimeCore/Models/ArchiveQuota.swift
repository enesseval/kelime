import Foundation
import GRDB

extension LocalDate {
    /// The Monday of this date's week (weeks run Monday to Sunday).
    public var weekStart: LocalDate {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let base = utc.date(from: DateComponents(year: year, month: month, day: day))!
        let weekday = utc.component(.weekday, from: base) // Sunday = 1
        return adding(days: -((weekday + 5) % 7))
    }
}

/// Free learners may open two puzzles a week from the archive; the quota renews on Monday.
/// Pro (and the trial) is unlimited. A puzzle opened this week, or played before, opens free.
public enum ArchiveQuota {
    public static let freePerWeek = 2

    /// The archive days opened in `today`'s week.
    public static func opened(today: LocalDate, db: Database) throws -> Set<String> {
        guard try Settings.string(.archiveWeek, in: db) == today.weekStart.string,
              let raw = try Settings.string(.archiveOpened, in: db) else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// Puzzles a free learner can still open this week.
    public static func remaining(today: LocalDate, db: Database) throws -> Int {
        max(0, freePerWeek - (try opened(today: today, db: db).count))
    }

    /// `played`: the puzzle already has solved words; opening it again never spends a slot.
    public static func canOpen(_ day: LocalDate, today: LocalDate, isPro: Bool, played: Bool = false, db: Database) throws -> Bool {
        if isPro || played { return true }
        let opened = try opened(today: today, db: db)
        return opened.contains(day.string) || opened.count < freePerWeek
    }

    /// Opens `day`: records it against this week's quota. False when the quota is used up
    /// (nothing is recorded); Pro is always true and records nothing.
    @discardableResult
    public static func open(_ day: LocalDate, today: LocalDate, isPro: Bool, played: Bool = false, db: Database) throws -> Bool {
        if isPro || played { return true }
        var opened = try opened(today: today, db: db)
        if opened.contains(day.string) { return true }
        guard opened.count < freePerWeek else { return false }
        opened.insert(day.string)
        try Settings.set(.archiveWeek, today.weekStart.string, in: db)
        try Settings.set(.archiveOpened, opened.sorted().joined(separator: ","), in: db)
        return true
    }
}
