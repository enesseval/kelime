import Foundation

/// The daily reminder's texts for the coming days (docs/V1_1_PLAN.md §1).
///
/// iOS can't run code when a local notification fires, so the app schedules one notification per
/// day ahead and rebuilds the plan whenever the streak can change (app opened, a day studied,
/// reminder time changed). Each planned day assumes nothing is studied between now and then;
/// studying reschedules, which drops that day's reminder.
public enum ReminderPlan {
    /// Days scheduled ahead. A learner away longer than this gets no more reminders until the
    /// app is opened again.
    public static let daysAhead = 14

    public struct Item: Equatable, Sendable {
        /// Days from today (0 = today).
        public var offset: Int
        public var title: String
        public var body: String
    }

    public static let regularTitle = "Tekrar zamanı"
    public static let regularBody = "Günde bir hatırlatma: 2 dakikalık bir Hızlı Tekrar seni bekliyor."
    public static let riskTitle = "Serin bu akşam bitiyor"
    public static func riskBody(_ days: Int) -> String { "\(days) günlük serin bu akşam bitiyor. 2 dakikalık bir tur yeter." }

    /// - Parameters:
    ///   - streak: the streak as of now.
    ///   - todayStillAhead: today's reminder time hasn't passed yet.
    public static func items(streak: StreakStatus, todayStillAhead: Bool, daysAhead: Int = daysAhead) -> [Item] {
        var items: [Item] = []
        for offset in 0..<daysAhead {
            if offset == 0 {
                // Studied today: no reminder today.
                guard todayStillAhead, !streak.studiedToday else { continue }
                items.append(streak.atRisk ? risk(0, streak.current) : regular(0))
            } else if offset == 1, streak.studiedToday, streak.current > 0 {
                // Studied today and nothing tomorrow yet: tomorrow evening the streak is at risk.
                items.append(risk(1, streak.current))
            } else {
                items.append(regular(offset))
            }
        }
        return items
    }

    private static func regular(_ offset: Int) -> Item { Item(offset: offset, title: regularTitle, body: regularBody) }
    private static func risk(_ offset: Int, _ days: Int) -> Item { Item(offset: offset, title: riskTitle, body: riskBody(days)) }
}
