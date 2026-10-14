import Foundation

/// Everything a widget needs to render one moment. Built from the shared database by
/// `WidgetTimelineBuilder`; the widget extension and the app's previews render it.
public struct WidgetSnapshot: Sendable, Equatable {
    /// Self-test shows the question first, then the answer later in the same slot.
    public enum Phase: Sendable, Equatable {
        case question
        case answer
    }

    public var date: Date
    public var slotStart: Date
    /// nil means the database has no content yet (the app was never opened).
    public var card: Card?
    public var state: LearningState
    public var mode: WidgetMode
    public var phase: Phase
    /// English options for the medium quiz widget.
    public var quizOptions: [String]
    /// The option the user tapped in this slot, if any.
    public var quizAnswer: String?
    /// Answers logged on this entry's local day, for the circular review ring.
    public var reviewedToday: Int
    public var dailyTarget: Int
    /// Up to three struggling words for the large widget, most recent first.
    public var struggling: [Card]
    /// Today's crossword progress (solved, total), nil before the puzzle is opened.
    public var puzzleProgress: PuzzleCount?
    /// Home-screen theme, already resolved for the user's entitlement.
    public var theme: WidgetThemeID

    public struct PuzzleCount: Sendable, Equatable {
        public var solved: Int
        public var total: Int
        public init(solved: Int, total: Int) { self.solved = solved; self.total = total }
    }

    public init(
        date: Date,
        slotStart: Date? = nil,
        card: Card?,
        state: LearningState = .new,
        mode: WidgetMode = .card,
        phase: Phase = .answer,
        quizOptions: [String] = [],
        quizAnswer: String? = nil,
        reviewedToday: Int = 0,
        dailyTarget: Int = WidgetTimelineBuilder.dailyTarget,
        struggling: [Card] = [],
        puzzleProgress: PuzzleCount? = nil,
        theme: WidgetThemeID = .paper
    ) {
        self.date = date
        self.slotStart = slotStart ?? date
        self.card = card
        self.state = state
        self.mode = mode
        self.phase = phase
        self.quizOptions = quizOptions
        self.quizAnswer = quizAnswer
        self.reviewedToday = reviewedToday
        self.dailyTarget = dailyTarget
        self.struggling = struggling
        self.puzzleProgress = puzzleProgress
        self.theme = theme
    }

    public var isEmpty: Bool { card == nil }

    /// Quiz result for the medium quiz widget: nil until answered.
    public var quizCorrect: Bool? {
        guard let quizAnswer, let card else { return nil }
        return quizAnswer == card.word
    }

    public static func empty(at date: Date) -> WidgetSnapshot {
        WidgetSnapshot(date: date, card: nil)
    }
}

extension Card {
    /// Self-test prompt: the first letter, then one blank per remaining letter ("r________").
    public var selfTestPattern: (first: String, blanks: String) {
        (String(word.prefix(1)), String(repeating: "_", count: max(word.count - 1, 0)))
    }

    /// First Turkish meaning, used in compact places like the inline widget.
    public var primaryMeaning: String { tr.first ?? "" }
}
