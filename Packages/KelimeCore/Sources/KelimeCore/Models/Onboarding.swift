import Foundation
import GRDB

/// The 5 widget themes. Paper is free; the rest are Pro.
public enum WidgetThemeID: String, Codable, Sendable, CaseIterable, Identifiable {
    case paper
    case ink
    case glass
    case ember
    case mono

    public var id: String { rawValue }
    public var isPro: Bool { self != .paper }

    /// Turkish name shown in the picker.
    public var name: String {
        switch self {
        case .paper: "Kâğıt"
        case .ink: "Mürekkep"
        case .glass: "Cam"
        case .ember: "Kor"
        case .mono: "Yalın"
        }
    }

    /// Pro themes fall back to Paper for free users.
    public func effective(isPro: Bool) -> WidgetThemeID {
        self.isPro && !isPro ? .paper : self
    }
}

/// Why the user is learning English (onboarding step 2).
public enum LearningGoal: String, Codable, Sendable, CaseIterable, Identifiable {
    case general
    case yds
    case work
    case travel

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .general: "Genel İngilizce"
        case .yds: "YDS / YÖKDİL"
        case .work: "İş hayatı"
        case .travel: "Seyahat ve dizi"
        }
    }
}

/// Everything onboarding collects. Saved in one transaction when the user finishes.
public struct OnboardingChoices: Sendable, Equatable {
    public var goal: LearningGoal
    public var examDate: LocalDate?
    public var level: CEFRLevel
    public var rotation: RotationInterval
    /// Minutes after midnight, or nil when the user skipped the reminder.
    public var reminderMinutes: Int?

    public init(goal: LearningGoal = .general, examDate: LocalDate? = nil, level: CEFRLevel = .b1, rotation: RotationInterval = .default, reminderMinutes: Int? = nil) {
        self.goal = goal
        self.examDate = examDate
        self.level = level
        self.rotation = rotation
        self.reminderMinutes = reminderMinutes
    }

    /// Decks the widget starts with: the level deck, plus the exam deck for YDS goals.
    /// Pro decks stay in the list so they switch on after a purchase; free users fall back to
    /// the free decks through `DeckID.entitled`.
    public var decks: [DeckID] {
        var decks: [DeckID] = []
        if let levelDeck = DeckID.allCases.first(where: { $0.level == level }) { decks.append(levelDeck) }
        if goal == .yds { decks.append(.yds) }
        for free in DeckID.freeDecks where !decks.contains(free) && level <= .b1 { decks.append(free) }
        return decks
    }

    public func save(db: Database) throws {
        var prefs = try Preferences.load(db)
        prefs.level = level
        prefs.enabledDecks = decks
        // No paywall in onboarding: Pro-only rhythms can't be chosen there.
        prefs.rotationInterval = rotation.isPro && !prefs.isPro ? .default : rotation
        try prefs.save(db)
        try Settings.set(.goal, goal.rawValue, in: db)
        try Settings.set(.examDate, goal == .yds ? examDate : nil, in: db)
        try Settings.set(.reminderTime, reminderMinutes, in: db)
        try Settings.set(.onboardingDone, true, in: db)
    }
}

/// Sample words shown per level on the onboarding level step.
public enum LevelSamples {
    public static func words(for level: CEFRLevel) -> [String] {
        switch level {
        case .a1: ["book", "happy", "water"]
        case .a2: ["borrow", "famous", "journey"]
        case .b1: ["reliable", "obvious", "achieve"]
        case .b2: ["reluctant", "hesitate", "significant"]
        case .c1: ["ambiguous", "meticulous", "mitigate"]
        }
    }
}
