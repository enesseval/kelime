import Foundation
import KelimeCore

/// Developer switches for Debug and TestFlight builds. Never available in App Store builds:
/// Release needs the `DEV_TOOLS` flag (Config/Shared.xcconfig) and a sandbox receipt.
enum DevTools {
    static var isAvailable: Bool {
        #if DEBUG
        return true
        #elseif DEV_TOOLS
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #else
        return false
        #endif
    }

    private static let forceProKey = "dev.forcePro"

    /// Treat the user as Pro without a purchase. On by default wherever dev tools exist.
    static var forcePro: Bool {
        get {
            guard isAvailable else { return false }
            return UserDefaults.standard.object(forKey: forceProKey) as? Bool ?? true
        }
        set { UserDefaults.standard.set(newValue, forKey: forceProKey) }
    }

    /// Forgets today's daily and personal puzzle progress.
    static func resetTodaysPuzzles(db: Database, clock: AppClock) throws {
        let day = clock.today.string
        try db.execute(sql: "DELETE FROM puzzle_progress WHERE puzzle_key LIKE ?", arguments: ["%-\(day)%"])
        try Settings.set(.dailyPuzzleSummary, nil as String?, in: db)
    }

    /// Removes today's Quick Review sessions, so the free daily limit is available again.
    static func resetQuickReviewLimit(db: Database, clock: AppClock) throws {
        try db.execute(
            sql: "UPDATE review_log SET session_id = NULL WHERE source = ? AND answered_on = ?",
            arguments: [ReviewSource.quickReview, clock.today]
        )
    }
}
