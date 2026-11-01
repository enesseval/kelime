import Foundation
import GRDB

/// Monday's look back at the past week: what was learned, what the widget showed, how Quick
/// Review went, the streak, and the word that took the most effort to learn.
public struct WeeklySummary: Sendable, Equatable {
    /// Monday of the summarised week.
    public var weekStart: LocalDate
    public var learned: Int
    public var struggling: Int
    /// Different words the widget showed that week.
    public var widgetWords: Int
    /// Quick Review answers that week, and how many were right.
    public var answers: Int
    public var correct: Int
    public var streak: Int
    /// The word answered wrong most often before it was learned this week.
    public var wordOfTheWeek: Card?

    public var accuracy: Double? { answers == 0 ? nil : Double(correct) / Double(answers) }

    /// Nothing happened that week: no summary to show.
    public var isEmpty: Bool { learned == 0 && answers == 0 && widgetWords == 0 }

    /// Self, or nil when the week is empty.
    public var nonEmpty: WeeklySummary? { isEmpty ? nil : self }
}

extension WeeklySummary {
    /// The summary of the week before the one containing `today`.
    public static func lastWeek(db: Database, clock: AppClock) throws -> WeeklySummary {
        let start = StatsQueries.weekStart(for: clock.today).adding(days: -7)
        return try week(starting: start, db: db, clock: clock)
    }

    public static func week(starting start: LocalDate, db: Database, clock: AppClock) throws -> WeeklySummary {
        let end = start.adding(days: 6)
        let learned = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM card_state WHERE state = ? AND last_answered_on BETWEEN ? AND ?
            """, arguments: [LearningState.learned, start, end]) ?? 0
        let struggling = try Int.fetchOne(db, sql: """
            SELECT COUNT(DISTINCT card_id) FROM review_log WHERE correct = 0 AND answered_on BETWEEN ? AND ?
            """, arguments: [start, end]) ?? 0
        let widgetWords = try Int.fetchOne(db, sql: """
            SELECT COUNT(DISTINCT card_id) FROM shown_log WHERE day BETWEEN ? AND ?
            """, arguments: [start, end]) ?? 0
        let row = try Row.fetchOne(db, sql: """
            SELECT COUNT(*) AS answers, COALESCE(SUM(correct), 0) AS correct FROM review_log
            WHERE source = ? AND answered_on BETWEEN ? AND ?
            """, arguments: [ReviewSource.quickReview, start, end])
        let wordID = try String.fetchOne(db, sql: """
            SELECT r.card_id FROM review_log r JOIN card_state s ON s.card_id = r.card_id
            WHERE r.correct = 0 AND r.answered_on <= ? AND s.state = ? AND s.last_answered_on BETWEEN ? AND ?
            GROUP BY r.card_id ORDER BY COUNT(*) DESC, r.card_id LIMIT 1
            """, arguments: [end, LearningState.learned, start, end])
        let days = try Set(LocalDate.fetchAll(db, sql: "SELECT day FROM streak_day WHERE day <= ?", arguments: [end]))
        let streak = Streak.compute(days: days, today: end, freezesPerWeek: Streak.freezes(isPro: try Settings.bool(.isPro, in: db))).current
        return WeeklySummary(
            weekStart: start,
            learned: learned,
            struggling: struggling,
            widgetWords: widgetWords,
            answers: row?["answers"] ?? 0,
            correct: row?["correct"] ?? 0,
            streak: streak,
            wordOfTheWeek: try wordID.flatMap { try Card.fetchOne(db, key: $0) }
        )
    }

    /// Whether Bugün should offer last week's summary: it's a new week and it hasn't been opened.
    public static func isNew(db: Database, clock: AppClock) throws -> Bool {
        let thisMonday = StatsQueries.weekStart(for: clock.today)
        return try Settings.date(.weeklySummarySeen, in: db) != thisMonday
    }

    public static func markSeen(db: Database, clock: AppClock) throws {
        try Settings.set(.weeklySummarySeen, StatsQueries.weekStart(for: clock.today), in: db)
    }
}
