import Foundation

/// Source of "now" and of the calendar used to turn it into local days.
///
/// Everything that needs the current time takes an `AppClock`, so tests can cross midnight and
/// DST boundaries. (Named `AppClock` to stay clear of the standard library's `Clock` protocol.)
public struct AppClock: Sendable {
    private let nowProvider: @Sendable () -> Date
    private let calendarProvider: @Sendable () -> Calendar

    public init(now: @escaping @Sendable () -> Date, calendar: @escaping @Sendable () -> Calendar) {
        self.nowProvider = now
        self.calendarProvider = calendar
    }

    public var now: Date { nowProvider() }
    public var calendar: Calendar { calendarProvider() }
    public var today: LocalDate { LocalDate(now, calendar: calendar) }

    /// The device clock and its current calendar and time zone, re-read on every call.
    public static let system = AppClock(now: { Date() }, calendar: { Calendar.autoupdatingCurrent })

    /// A clock frozen at `date` in `timeZone`. For tests and previews.
    public static func fixed(_ date: Date, timeZone: TimeZone) -> AppClock {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let calendar = gregorian
        return AppClock(now: { date }, calendar: { calendar })
    }
}
