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
                break
            }
        }

        if event != .hintUsed {
            next.lastAnsweredOn = day
        }
        return next
    }
}
