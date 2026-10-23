import Foundation

/// Something the user did with a card.
public enum LearningEvent: Sendable, Equatable {
    /// A Quick Review, crossword or widget quiz answer.
    case answered(correct: Bool)
    /// Any crossword hint: "Harf aç", a failed "Kelimeyi kontrol et", "Kelimeyi göster".
    case hintUsed
    /// "Biliyorum" in the widget or the app.
    case markedKnown
    /// "Zorlanıyorum" in the widget or the app.
    case markedStruggling
}

/// The learning-state rules, as pure functions.
///
/// - Wrong answer or any hint → struggling, streak resets to 0.
/// - Correct answer on a new word → learned.
/// - Correct answer on a struggling word increments the streak, at most once per local day;
///   two correct answers on different local days → learned.
/// - "Biliyorum" → learned. "Zorlanıyorum" → struggling.
public enum LearningRules {
    /// Correct answers on different days needed to move a struggling word to learned.
    public static let streakToLearn = 2

    public static func apply(_ event: LearningEvent, to current: CardState, on day: LocalDate) -> CardState {
        var next = current
        switch event {
        case .answered(correct: false), .hintUsed, .markedStruggling:
            next.state = .struggling
            next.correctStreak = 0

        case .markedKnown:
            next.state = .learned
            next.correctStreak = max(current.correctStreak, 1)

        case .answered(correct: true):
            switch current.state {
            case .new:
                next.state = .learned
                next.correctStreak = 1
            case .struggling:
                // A streak > 0 means `lastAnsweredOn` is the day of the last correct answer.
                let alreadyCountedToday = current.correctStreak > 0 && current.lastAnsweredOn == day
                if !alreadyCountedToday {
                    next.correctStreak += 1
                }
                if next.correctStreak >= streakToLearn {
                    next.state = .learned
                }
            case .learned:
                // A learned word answered again: one review step up, once a day.
                if current.lastAnsweredOn != day {
                    next.correctStreak += 1
                }
            }
        }

        if event != .hintUsed {
            next.lastAnsweredOn = day
        }
        return next
    }
}

/// When learned words come back so they are not forgotten: after about 3, 7, 21, 60 and then
/// every 120 days, counted from the last answer. Each correct answer is a step; a wrong one
/// makes the word struggling again.
public enum SpacedReview {
    static let intervals = [3, 7, 21, 60, 120]

    /// Days to wait after the last answer, for a learned word at `streak`.
    public static func interval(streak: Int) -> Int {
        intervals[min(max(streak, 1), intervals.count) - 1]
    }

    /// The day a learned word is due again, or nil (not learned, or never answered).
    public static func dueDate(_ state: CardState) -> LocalDate? {
        guard state.state == .learned, let last = state.lastAnsweredOn else { return nil }
        return last.adding(days: interval(streak: state.correctStreak))
    }

    public static func isDue(_ state: CardState, on day: LocalDate) -> Bool {
        guard let due = dueDate(state) else { return false }
        return due.days(since: day) <= 0
    }
}
