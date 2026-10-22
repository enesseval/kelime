import Foundation
import KelimeCore
import UserNotifications

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

    // MARK: - Widget check reminders

    static let checkReminderPrefix = "dev.check."
    private static let checkRemindersKey = "dev.checkReminders"

    static var checkRemindersOn: Bool {
        UserDefaults.standard.bool(forKey: checkRemindersKey)
    }

    /// A notification at :00 and :30 asking to tap the widget, so the log collects a tap
    /// right after every 30-minute change.
    static func setCheckReminders(_ on: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let ids = ["00", "30"].map { checkReminderPrefix + $0 }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        UserDefaults.standard.set(false, forKey: checkRemindersKey)
        guard on else { return true }
        var allowed = await Reminder.isAuthorized()
        if !allowed { allowed = await Reminder.requestAuthorization() }
        guard allowed else { return false }
        for (id, minute) in zip(ids, [0, 30]) {
            let content = UNMutableNotificationContent()
            content.title = "Widget kontrolü"
            content.body = "Kelime az önce değişmiş olmalı. Kilit ekranındaki widget'a dokun."
            content.sound = .default
            var components = DateComponents()
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        UserDefaults.standard.set(true, forKey: checkRemindersKey)
        return true
    }
}
