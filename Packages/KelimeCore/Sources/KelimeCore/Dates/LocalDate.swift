import Foundation
import GRDB

/// A calendar day on the device's local calendar, stored as `YYYY-MM-DD`.
///
/// Every "day" concept in the app (daily puzzle, free-session reset, learning "different days",
/// weekly stats) uses this type. Never derive a day from UTC: `ISO8601DateFormatter` and
/// `Date.description` are UTC by default and must not be used for day keys.
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The local day that contains `date` in `calendar` (its time zone included).
    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Parses `YYYY-MM-DD`. Returns nil for anything else, including impossible dates.
    public init?(string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        guard let date = gregorian.date(from: DateComponents(year: y, month: m, day: d)),
              gregorian.component(.day, from: date) == d
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Start of this day in `calendar`'s time zone. Handles days that don't start at 00:00 (DST).
    public func startDate(in calendar: Calendar) -> Date {
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return calendar.startOfDay(for: noon)
    }

    public func adding(days: Int) -> LocalDate {
        // Day arithmetic is pure calendar math, independent of any time zone.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let base = utc.date(from: DateComponents(year: year, month: month, day: day))!
        return LocalDate(utc.date(byAdding: .day, value: days, to: base)!, calendar: utc)
    }

    /// Whole days from `other` to `self` (positive when `self` is later).
    public func days(since other: LocalDate) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let a = utc.date(from: DateComponents(year: other.year, month: other.month, day: other.day))!
        let b = utc.date(from: DateComponents(year: year, month: month, day: day))!
        return utc.dateComponents([.day], from: a, to: b).day!
    }

    /// Fixed epoch for day indexes (daily puzzle rotation).
    public static let epoch = LocalDate(year: 2026, month: 1, day: 1)

    /// Days since `LocalDate.epoch`. Negative for earlier days.
    public var dayIndex: Int { days(since: .epoch) }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension LocalDate: CustomStringConvertible {
    public var description: String { string }
}

extension LocalDate: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = LocalDate(string: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid LocalDate \(raw)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension LocalDate: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { string.databaseValue }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> LocalDate? {
        String.fromDatabaseValue(dbValue).flatMap(LocalDate.init(string:))
    }
}
