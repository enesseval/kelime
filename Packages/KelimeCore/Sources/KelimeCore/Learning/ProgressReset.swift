import GRDB

/// Starts the learner over: progress, reviews, puzzles, the widget queue and every choice made
/// in onboarding. Content, the learner's own lists, the purchase and the developer widget log stay.
public enum ProgressReset {
    /// Bumped when an update changes the content model so much that old progress no longer
    /// fits (1: units replace word decks, build 13). Installs below it are reset once.
    public static let epoch = 1

    static let keptSettings: [SettingKey] = [.contentVersion, .contentCheckedAt, .isPro]

    public static func reset(db: Database) throws {
        for table in ["card_state", "review_log", "puzzle_progress", "widget_queue"] {
            try db.execute(sql: "DELETE FROM \(table)")
        }
        try db.execute(literal: "DELETE FROM settings WHERE key NOT IN \(keptSettings.map(\.rawValue))")
        // Until onboarding picks a level, the widget shows the first course, not B1 words.
        var prefs = try Preferences.load(db)
        prefs.level = .a1
        prefs.enabledDecks = [.a1]
        try prefs.save(db)
        try Settings.set(.progressEpoch, epoch, in: db)
    }

    /// Resets once per epoch. Returns true when it reset, so onboarding shows again.
    @discardableResult
    public static func resetIfNeeded(db: Database) throws -> Bool {
        guard (try Settings.int(.progressEpoch, in: db) ?? 0) < epoch else { return false }
        try reset(db: db)
        return true
    }
}
