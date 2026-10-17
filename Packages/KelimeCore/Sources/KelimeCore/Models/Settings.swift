import Foundation
import GRDB

/// Keys of the key-value `settings` table.
public enum SettingKey: String, CaseIterable, Sendable {
    case level
    case goal
    case examDate = "exam_date"
    case enabledDecks = "enabled_decks"
    case rotationInterval = "rotation_interval"
    case defaultWidgetMode = "default_widget_mode"
    case theme
    case reminderTime = "reminder_time"
    case isPro = "is_pro"
    case onboardingDone = "onboarding_done"
    case contentVersion = "content_version"
    case widgetBannerDismissed = "widget_banner_dismissed"
    /// "YYYY-MM-DD|solved|total" for today's daily puzzle; the large widget shows it.
    case dailyPuzzleSummary = "daily_puzzle_summary"
    /// Speech rate multiplier for pronunciation, e.g. "0.9".
    case speechRate = "speech_rate"
    /// Developer measurement mode: the widget gets one entry at a time and asks again at the
    /// next slot, so WidgetLog shows how often iOS really reloads it.
    case widgetProbe = "widget_probe"
}

struct SettingRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "settings"
    var key: String
    var value: String
}

/// Typed access to the `settings` table. Values are stored as text.
public enum Settings {
    public static func string(_ key: SettingKey, in db: Database) throws -> String? {
        try SettingRow.fetchOne(db, key: key.rawValue)?.value
    }

    public static func set(_ key: SettingKey, _ value: String?, in db: Database) throws {
        if let value {
            try SettingRow(key: key.rawValue, value: value).save(db)
        } else {
            _ = try SettingRow.deleteOne(db, key: key.rawValue)
        }
    }

    public static func int(_ key: SettingKey, in db: Database) throws -> Int? {
        try string(key, in: db).flatMap { Int($0) }
    }

    public static func set(_ key: SettingKey, _ value: Int?, in db: Database) throws {
        try set(key, value.map(String.init), in: db)
    }

    public static func bool(_ key: SettingKey, in db: Database) throws -> Bool {
        try string(key, in: db) == "1"
    }

    public static func set(_ key: SettingKey, _ value: Bool, in db: Database) throws {
        try set(key, value ? "1" : "0", in: db)
    }

    public static func date(_ key: SettingKey, in db: Database) throws -> LocalDate? {
        try string(key, in: db).flatMap(LocalDate.init(string:))
    }

    public static func set(_ key: SettingKey, _ value: LocalDate?, in db: Database) throws {
        try set(key, value?.string, in: db)
    }
}
