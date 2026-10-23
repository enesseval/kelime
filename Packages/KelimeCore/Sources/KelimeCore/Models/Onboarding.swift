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

/// Everything onboarding collects. Saved in one transaction when the user finishes.
public struct OnboardingChoices: Sendable, Equatable {
    public var level: CEFRLevel
    /// Minutes after midnight, or nil when the user skipped the reminder.
    public var reminderMinutes: Int?

    public init(level: CEFRLevel = .b1, reminderMinutes: Int? = nil) {
        self.level = level
        self.reminderMinutes = reminderMinutes
    }

    /// Decks the widget starts with: the level deck, plus the basic word decks below B2.
    public var decks: [DeckID] {
        var decks: [DeckID] = []
        if let levelDeck = DeckID.allCases.first(where: { $0.level == level }) { decks.append(levelDeck) }
        // Beginners stay in the A1 course; others get the basic word decks as well.
        if level > .a1 {
            for basic in DeckID.basicDecks where !decks.contains(basic) && level <= .b1 { decks.append(basic) }
        }
        return decks
    }

    public func save(db: Database) throws {
        var prefs = try Preferences.load(db)
        prefs.level = level
        // A level with units is the whole content: only its course.
        prefs.enabledDecks = try Curriculum.levels(db: db).contains(level) ? decks.filter { $0.level == level } : decks
        try prefs.save(db)
        try Settings.set(.reminderTime, reminderMinutes, in: db)
        try Settings.set(.onboardingDone, true, in: db)
    }
}

/// The optional exam countdown on Bugün, set in Ayarlar.
public enum ExamCountdown {
    public static let exams: [DeckID] = [.yds, .yokdil, .ielts]

    /// The exam and its date, or nil when none is set.
    public static func load(db: Database) throws -> (exam: DeckID, date: LocalDate)? {
        guard let date = try Settings.date(.examDate, in: db) else { return nil }
        // Installs from before the exam choice only had a date, for YDS.
        let exam = try Settings.string(.exam, in: db).flatMap(DeckID.init(rawValue:)) ?? .yds
        return (exam, date)
    }

    /// Days left until the exam, or nil when none is set or it is over.
    public static func daysLeft(db: Database, clock: AppClock) throws -> (exam: DeckID, days: Int)? {
        guard let plan = try load(db: db), let days = StatsQueries.daysUntilExam(plan.date, clock: clock) else { return nil }
        return (plan.exam, days)
    }

    public static func set(_ exam: DeckID, date: LocalDate, db: Database) throws {
        try Settings.set(.exam, exam.rawValue, in: db)
        try Settings.set(.examDate, date, in: db)
    }

    public static func clear(db: Database) throws {
        try Settings.set(.exam, nil as String?, in: db)
        try Settings.set(.examDate, nil as LocalDate?, in: db)
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
        case .c2: ["ubiquitous", "ephemeral", "esoteric"]
        }
    }
}

/// Where the learner stands on the exam plan (Pro): the words of the exam's list still to learn,
/// spread over the days left.
public struct ExamPlanStatus: Sendable, Equatable {
    public var exam: DeckID
    public var daysLeft: Int
    /// Words of the exam list not learned yet.
    public var remaining: Int
    /// Words to study today to finish the list by the exam.
    public var dailyTarget: Int
    /// Words of the exam list answered today.
    public var doneToday: Int
    /// The exam list is on the widget.
    public var listOnWidget: Bool

    public var fraction: Double { dailyTarget == 0 ? 1 : min(Double(doneToday) / Double(dailyTarget), 1) }
}

public enum ExamPlan {
    public static func status(db: Database, clock: AppClock) throws -> ExamPlanStatus? {
        guard let countdown = try ExamCountdown.daysLeft(db: db, clock: clock),
              let filter = CardQueries.deckFilter([countdown.exam]) else { return nil }
        let remaining = try Int.fetchOne(db, SQLRequest<Int>("""
            SELECT COUNT(*) FROM card c LEFT JOIN card_state s ON s.card_id = c.id
            WHERE \(filter) AND COALESCE(s.state, 'new') <> 'learned'
            """)) ?? 0
        let doneToday = try Int.fetchOne(db, SQLRequest<Int>("""
            SELECT COUNT(DISTINCT r.card_id) FROM review_log r JOIN card c ON c.id = r.card_id
            WHERE r.answered_on = \(clock.today) AND \(filter)
            """)) ?? 0
        let days = max(countdown.days, 1)
        let target = remaining == 0 ? 0 : min(max(Int((Double(remaining) / Double(days)).rounded(.up)), 1), remaining)
        return ExamPlanStatus(
            exam: countdown.exam,
            daysLeft: countdown.days,
            remaining: remaining,
            dailyTarget: target,
            doneToday: doneToday,
            listOnWidget: try Preferences.load(db).enabledDecks.contains(countdown.exam)
        )
    }
}
