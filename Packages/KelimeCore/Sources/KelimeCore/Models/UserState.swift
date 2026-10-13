import Foundation
import GRDB

/// Learning state of a card. Shown as Yeni / Zorlanılan / Öğrenildi.
public enum LearningState: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case new
    case struggling
    case learned
}

/// Per-card user progress. A missing row means the card is `.new` and was never shown.
public struct CardState: Codable, Sendable, Hashable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card_state"

    public var cardID: String
    public var state: LearningState
    public var correctStreak: Int
    public var lastShownAt: Date?
    public var lastAnsweredOn: LocalDate?
    public var timesShown: Int
    public var favorite: Bool

    public init(
        cardID: String,
        state: LearningState = .new,
        correctStreak: Int = 0,
        lastShownAt: Date? = nil,
        lastAnsweredOn: LocalDate? = nil,
        timesShown: Int = 0,
        favorite: Bool = false
    ) {
        self.cardID = cardID
        self.state = state
        self.correctStreak = correctStreak
        self.lastShownAt = lastShownAt
        self.lastAnsweredOn = lastAnsweredOn
        self.timesShown = timesShown
        self.favorite = favorite
    }

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
        case state
        case correctStreak = "correct_streak"
        case lastShownAt = "last_shown_at"
        case lastAnsweredOn = "last_answered_on"
        case timesShown = "times_shown"
        case favorite
    }

    public enum Columns {
        public static let cardID = Column(CodingKeys.cardID)
        public static let state = Column(CodingKeys.state)
        public static let favorite = Column(CodingKeys.favorite)
    }
}

/// One rotation slot of the widget timeline, precomputed for the next 24 hours.
public struct WidgetQueueEntry: Codable, Sendable, Hashable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "widget_queue"

    public var slotStart: Date
    public var cardID: String
    /// English options for the medium quiz widget, the answer included.
    public var quizOptions: [String]
    /// The option the user tapped, kept until the next slot.
    public var quizAnswer: String?

    public init(slotStart: Date, cardID: String, quizOptions: [String], quizAnswer: String? = nil) {
        self.slotStart = slotStart
        self.cardID = cardID
        self.quizOptions = quizOptions
        self.quizAnswer = quizAnswer
    }

    enum CodingKeys: String, CodingKey {
        case slotStart = "slot_start"
        case cardID = "card_id"
        case quizOptions = "quiz_options"
        case quizAnswer = "quiz_answer"
    }

    public enum Columns {
        public static let slotStart = Column(CodingKeys.slotStart)
    }
}

/// Where an answer came from.
public enum ReviewSource: String, Codable, Sendable, DatabaseValueConvertible {
    case quickReview
    case puzzle
    case widget
    case wordDetail
}

/// One answered question. Feeds "this week" stats and the free daily limit.
public struct ReviewLog: Codable, Sendable, Hashable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "review_log"

    public var id: Int64?
    public var cardID: String
    public var answeredAt: Date
    public var answeredOn: LocalDate
    public var correct: Bool
    public var source: ReviewSource
    /// Groups the answers of one Quick Review session.
    public var sessionID: String?

    public init(id: Int64? = nil, cardID: String, answeredAt: Date, answeredOn: LocalDate, correct: Bool, source: ReviewSource, sessionID: String? = nil) {
        self.id = id
        self.cardID = cardID
        self.answeredAt = answeredAt
        self.answeredOn = answeredOn
        self.correct = correct
        self.source = source
        self.sessionID = sessionID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cardID = "card_id"
        case answeredAt = "answered_at"
        case answeredOn = "answered_on"
        case correct, source
        case sessionID = "session_id"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Saved state of a daily or personal crossword.
public struct PuzzleProgress: Codable, Sendable, Hashable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "puzzle_progress"

    public var puzzleKey: String
    /// Typed letters, row-major, encoded as JSON by the crossword feature.
    public var cells: String
    public var hintsUsed: Int
    public var completedAt: Date?
    public var seconds: Int

    public init(puzzleKey: String, cells: String, hintsUsed: Int = 0, completedAt: Date? = nil, seconds: Int = 0) {
        self.puzzleKey = puzzleKey
        self.cells = cells
        self.hintsUsed = hintsUsed
        self.completedAt = completedAt
        self.seconds = seconds
    }

    enum CodingKeys: String, CodingKey {
        case puzzleKey = "puzzle_key"
        case cells
        case hintsUsed = "hints_used"
        case completedAt = "completed_at"
        case seconds
    }
}
