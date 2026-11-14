import Foundation
import GRDB

/// Free learners may open two puzzles a week from the archive; the quota renews on Monday.
/// Pro (and the trial) is unlimited. A puzzle opened this week, or played before, opens free.
public enum ArchiveQuota {
    public static let freePerWeek = 2

    /// The archive days opened in `today`'s week.
    public static func opened(today: LocalDate, db: Database) throws -> Set<String> {
        guard try Settings.string(.archiveWeek, in: db) == StatsQueries.weekStart(for: today).string,
              let raw = try Settings.string(.archiveOpened, in: db) else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// Puzzles a free learner can still open this week.
    public static func remaining(today: LocalDate, db: Database) throws -> Int {
        max(0, freePerWeek - (try opened(today: today, db: db).count))
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
        try Settings.set(.archiveWeek, StatsQueries.weekStart(for: today).string, in: db)
        try Settings.set(.archiveOpened, opened.sorted().joined(separator: ","), in: db)
        return true
    }
}
