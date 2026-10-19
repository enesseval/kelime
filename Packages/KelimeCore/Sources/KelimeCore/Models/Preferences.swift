import Foundation
import GRDB

/// How often the widget card changes.
public enum RotationInterval: Int, Codable, Sendable, CaseIterable {
    case thirtyMinutes = 30
    case oneHour = 60
    case threeHours = 180
    case daily = 1440

    public var minutes: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    /// 30 minutes and 1 hour are Pro.
    public var isPro: Bool { self == .thirtyMinutes || self == .oneHour }

    public static let `default` = RotationInterval.threeHours

    /// The interval actually used: Pro-only choices fall back to the default for free users.
    public func effective(isPro: Bool) -> RotationInterval {
        self.isPro && !isPro ? .default : self
    }
}

/// Display mode of the rectangular lock-screen widget.
public enum WidgetMode: String, Codable, Sendable, CaseIterable {
    case card
    case dictionary
    case wordAndSentence
    case sentence
    case selfTest

    /// Short name, e.g. for the widget's edit menu.
    public var label: String {
        switch self {
        case .card: "Kart"
        case .dictionary: "Sözlük"
        case .wordAndSentence: "Kelime ve cümle"
        case .sentence: "Örnek cümle"
        case .selfTest: "Kendini sına"
        }
    }

    /// What the mode shows, in one line.
    public var detail: String {
        switch self {
        case .card: "Büyük kelime, altında türü ve Türkçe anlamı"
        case .dictionary: "Arka plansız, sözlük gibi: KELİME (tür) ve anlamı"
        case .wordAndSentence: "Kelime ve İngilizce örnek cümlesi"
        case .sentence: "İngilizce cümle, altında Türkçesi"
        case .selfTest: "Önce anlam ve ilk harf, yarım saat içinde cevap"
        }
    }
}

/// The settings the scheduler and widgets need, with defaults applied.
public struct Preferences: Sendable, Equatable {
    public var level: CEFRLevel
    public var enabledDecks: [DeckID]
    public var rotationInterval: RotationInterval
    public var defaultWidgetMode: WidgetMode
    public var theme: WidgetThemeID
    public var isPro: Bool

    public init(
        level: CEFRLevel = .b1,
        enabledDecks: [DeckID] = DeckID.basicDecks,
        rotationInterval: RotationInterval = .default,
        defaultWidgetMode: WidgetMode = .card,
        theme: WidgetThemeID = .paper,
        isPro: Bool = false
    ) {
        self.level = level
        self.enabledDecks = enabledDecks
        self.rotationInterval = rotationInterval
        self.defaultWidgetMode = defaultWidgetMode
        self.theme = theme
        self.isPro = isPro
    }

    /// Decks the widget and reviews may draw from.
    public var entitledDecks: [DeckID] { DeckID.entitled(enabled: enabledDecks, isPro: isPro) }

    public var effectiveRotation: RotationInterval { rotationInterval.effective(isPro: isPro) }
    public var effectiveTheme: WidgetThemeID { theme.effective(isPro: isPro) }

    public static func load(_ db: Database) throws -> Preferences {
        var p = Preferences()
        if let raw = try Settings.string(.level, in: db), let level = CEFRLevel(rawValue: raw) {
            p.level = level
        }
        if let raw = try Settings.string(.enabledDecks, in: db) {
            p.enabledDecks = raw.split(separator: ",").compactMap { DeckID(rawValue: String($0)) }
        }
        if let minutes = try Settings.int(.rotationInterval, in: db), let interval = RotationInterval(rawValue: minutes) {
            p.rotationInterval = interval
        }
        if let raw = try Settings.string(.defaultWidgetMode, in: db), let mode = WidgetMode(rawValue: raw) {
            p.defaultWidgetMode = mode
        }
        if let raw = try Settings.string(.theme, in: db), let theme = WidgetThemeID(rawValue: raw) {
            p.theme = theme
        }
        p.isPro = try Settings.bool(.isPro, in: db)
        return p
    }

    public func save(_ db: Database) throws {
        try Settings.set(.level, level.rawValue, in: db)
        try Settings.set(.enabledDecks, enabledDecks.map(\.rawValue).joined(separator: ","), in: db)
        try Settings.set(.rotationInterval, rotationInterval.minutes, in: db)
        try Settings.set(.defaultWidgetMode, defaultWidgetMode.rawValue, in: db)
        try Settings.set(.theme, theme.rawValue, in: db)
        try Settings.set(.isPro, isPro, in: db)
    }
}
