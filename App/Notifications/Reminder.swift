import Foundation
import UIKit
import KelimeCore
import UserNotifications

/// The daily reminder at a user-chosen time, planned a few days ahead. No server, no remote
/// notifications.
enum Reminder {
    static let identifier = "daily-reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Schedules (or replaces) the daily reminders at `minutes` after midnight: one per day for
    /// `ReminderPlan.daysAhead` days, none today when today is already studied, and the streak
    /// text when the streak is at risk (docs/V1_1_PLAN.md §1).
    static func schedule(minutes: Int, streak: StreakStatus, now: Date = .now, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        await cancelAll(center)
        let today = LocalDate(now, calendar: calendar)
        let todayAt = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: now) ?? now
        for item in ReminderPlan.items(streak: streak, todayStillAhead: todayAt > now) {
            let day = today.adding(days: item.offset)
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: minutes / 60, minute: minutes % 60)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier + "-" + day.string, content: content, trigger: trigger))
        }
    }

    static func cancel() {
        Task { await cancelAll(UNUserNotificationCenter.current()) }
    }

    /// Removes the planned days and the old repeating reminder (1.0 scheduled `daily-reminder`).
    private static func cancelAll(_ center: UNUserNotificationCenter) async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(identifier) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// Receives notification taps. Each response is handled once, routed, then cleared; duplicate
/// deliveries of the same response are ignored.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor private var handled: Set<String> = []
    @MainActor private var pending: String?
    @MainActor var onReminderTap: (() -> Void)? {
        didSet { flushPending() }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Developer check reminders only ask the user to tap the widget; they open nothing.
        if response.notification.request.identifier.hasPrefix(DevTools.checkReminderPrefix) { return }
        let key = response.notification.request.identifier + "|" + String(response.notification.date.timeIntervalSince1970)
        await MainActor.run {
            guard !handled.contains(key) else { return }
            handled.insert(key)
            pending = key
            flushPending()
        }
        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
    }

    @MainActor private func flushPending() {
        guard pending != nil, let onReminderTap else { return }
        pending = nil
        onReminderTap()
    }
}
