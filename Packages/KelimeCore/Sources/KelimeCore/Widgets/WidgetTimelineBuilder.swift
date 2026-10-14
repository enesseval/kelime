import Foundation
import GRDB

/// Turns `widget_queue` into timeline snapshots for the next 24 hours.
public enum WidgetTimelineBuilder {
    /// Reviews per day shown as a full ring. One Quick Review session.
    public static let dailyTarget = 10
    /// Self-test reveals the answer at `start + min(interval / 2, 30 min)`.
    public static let maxRevealDelay: TimeInterval = 30 * 60

    public static func revealDelay(for interval: RotationInterval) -> TimeInterval {
        min(interval.seconds / 2, maxRevealDelay)
    }

    /// Snapshots from the current slot onward. Refills the queue first, so this writes.
    /// `mode` nil uses the app's default widget mode.
    public static func build(
        db: Database,
        clock: AppClock,
        mode: WidgetMode? = nil,
        using rng: inout some RandomNumberGenerator
    ) throws -> [WidgetSnapshot] {
        let now = clock.now
        let calendar = clock.calendar
        let prefs = try Preferences.load(db)
        let resolvedMode = mode ?? prefs.defaultWidgetMode
        let queue = try WidgetQueue.refill(db: db, clock: clock, using: &rng)
        guard !queue.isEmpty else { return [.empty(at: now)] }

        let ids = Array(Set(queue.map(\.cardID)))
        let cards = Dictionary(uniqueKeysWithValues: try Card.fetchAll(db, keys: ids).map { ($0.id, $0) })
        let states = Dictionary(uniqueKeysWithValues: try CardState.fetchAll(db, keys: ids).map { ($0.cardID, $0.state) })
        let struggling = try strugglingCards(db: db, limit: 3)
        let puzzle = try DailyPuzzleSummary.load(db: db)
        var reviewsByDay: [LocalDate: Int] = [:]
        func reviews(on date: Date) throws -> Int {
            let day = LocalDate(date, calendar: calendar)
            if let cached = reviewsByDay[day] { return cached }
            let count = try reviewCount(on: day, db: db)
            reviewsByDay[day] = count
            return count
        }

        let delay = revealDelay(for: prefs.effectiveRotation)
        var snapshots: [WidgetSnapshot] = []
        for entry in queue {
            guard let card = cards[entry.cardID] else { continue }
            let base = WidgetSnapshot(
                date: entry.slotStart,
                slotStart: entry.slotStart,
                card: card,
                state: states[card.id] ?? .new,
                mode: resolvedMode,
                phase: resolvedMode == .selfTest ? .question : .answer,
                quizOptions: entry.quizOptions,
                quizAnswer: entry.quizAnswer,
                reviewedToday: try reviews(on: entry.slotStart),
                struggling: struggling,
                puzzleProgress: puzzle.flatMap { summary in
                    summary.day == LocalDate(entry.slotStart, calendar: calendar)
                        ? WidgetSnapshot.PuzzleCount(solved: summary.solved, total: summary.total) : nil
                },
                theme: prefs.effectiveTheme
            )
            snapshots.append(base)
            if resolvedMode == .selfTest {
                var answer = base
                answer.date = entry.slotStart.addingTimeInterval(delay)
                answer.phase = .answer
                answer.reviewedToday = try reviews(on: answer.date)
                snapshots.append(answer)
            }
        }
        return snapshots.isEmpty ? [.empty(at: now)] : snapshots
    }

    /// Answers logged on `day`.
    public static func reviewCount(on day: LocalDate, db: Database) throws -> Int {
        try ReviewLog.filter(Column("answered_on") == day).fetchCount(db)
    }

    /// Struggling cards, most recently answered first.
    public static func strugglingCards(db: Database, limit: Int) throws -> [Card] {
        try Card.fetchAll(db, sql: """
            SELECT c.* FROM card c
            JOIN card_state s ON s.card_id = c.id
            WHERE s.state = ?
            ORDER BY s.last_answered_on DESC, c.word
            LIMIT ?
            """, arguments: [LearningState.struggling, limit])
    }

    /// Ring snapshots: today's count now, and a reset entry at the next local midnight.
    public static func ringSnapshots(db: Database, clock: AppClock) throws -> [WidgetSnapshot] {
        let now = clock.now
        let today = LocalDate(now, calendar: clock.calendar)
        let midnight = today.adding(days: 1).startDate(in: clock.calendar)
        let hasContent = try Card.fetchCount(db) > 0
        let card: Card? = hasContent ? try Card.limit(1).fetchOne(db) : nil
        return [
            WidgetSnapshot(date: now, card: card, reviewedToday: try reviewCount(on: today, db: db)),
            WidgetSnapshot(date: midnight, card: card, reviewedToday: 0),
        ]
    }
}

/// The logic behind the widget's interactive buttons. The App Intents in the widget extension
/// call these, then reload timelines.
public enum WidgetActions {
    public static func markKnown(cardID: String, db: Database, clock: AppClock) throws {
        try LearningStore.record(.markedKnown, cardID: cardID, source: .widget, clock: clock, db: db)
    }

    public static func markStruggling(cardID: String, db: Database, clock: AppClock) throws {
        try LearningStore.record(.markedStruggling, cardID: cardID, source: .widget, clock: clock, db: db)
    }

    /// Records a quiz answer once per slot. Returns whether it was correct, or nil when the
    /// current slot shows another card or was already answered.
    @discardableResult
    public static func answerQuiz(cardID: String, option: String, db: Database, clock: AppClock) throws -> Bool? {
        guard let entry = try WidgetQueue.current(db: db, clock: clock),
              entry.cardID == cardID, entry.quizAnswer == nil,
              let card = try Card.fetchOne(db, key: cardID)
        else { return nil }
        let correct = option == card.word
        try WidgetQueue.recordQuizAnswer(option, slotStart: entry.slotStart, db: db)
        try LearningStore.record(.answered(correct: correct), cardID: cardID, source: .widget, clock: clock, db: db)
        return correct
    }
}
