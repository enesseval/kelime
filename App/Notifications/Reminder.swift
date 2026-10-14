import Foundation
import UIKit
import UserNotifications

/// One local daily reminder at a user-chosen time. No server, no remote notifications.
enum Reminder {
    static let identifier = "daily-reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Schedules (or replaces) the daily reminder at `minutes` after midnight.
    static func schedule(minutes: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Tekrar zamanı"
        content.body = "Günde bir hatırlatma: 2 dakikalık bir Hızlı Tekrar seni bekliyor."
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
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
