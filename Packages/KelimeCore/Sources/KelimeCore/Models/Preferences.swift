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

    public static let `default` = RotationInterval.threeHours

    /// The interval actually used: without Pro every widget changes every 3 hours.
    public func effective(isPro: Bool) -> RotationInterval {
        isPro ? self : .default
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
        case .selfTest: "Önce anlam ve ilk harf, biraz sonra cevap"
        }
    }
}

/// Which cards the widget shows: words, phrases or both.
public enum WidgetContent: String, Codable, Sendable, CaseIterable {
    case all
    case words
    case phrases

    public var label: String {
        switch self {
        case .all: "Kelime ve kalıp"
        case .words: "Sadece kelime"
        case .phrases: "Sadece kalıp"
        }
    }

    /// SQL condition on `card c`, or nil for everything.
    var condition: SQL? {
        switch self {
        case .all: nil
        case .words: "c.pos <> \(PartOfSpeech.phrase.rawValue)"
        case .phrases: "c.pos = \(PartOfSpeech.phrase.rawValue)"
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
    public var widgetContent: WidgetContent
    public var isPro: Bool

    public init(
        level: CEFRLevel = .b1,
        enabledDecks: [DeckID] = DeckID.basicDecks,
        rotationInterval: RotationInterval = .default,
        defaultWidgetMode: WidgetMode = .card,
        theme: WidgetThemeID = .paper,
        widgetContent: WidgetContent = .all,
        isPro: Bool = false
    ) {
        self.level = level
        self.enabledDecks = enabledDecks
        self.rotationInterval = rotationInterval
        self.defaultWidgetMode = defaultWidgetMode
        self.theme = theme
        self.widgetContent = widgetContent
        self.isPro = isPro
    }

    /// Decks the widget and reviews may draw from.
    public var entitledDecks: [DeckID] { DeckID.entitled(enabled: enabledDecks) }

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
        if let raw = try Settings.string(.widgetContent, in: db), let content = WidgetContent(rawValue: raw) {
            p.widgetContent = content
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
        try Settings.set(.widgetContent, widgetContent.rawValue, in: db)
        try Settings.set(.isPro, isPro, in: db)
    }
}
