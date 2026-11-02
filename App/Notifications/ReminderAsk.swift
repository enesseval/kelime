import KelimeUI
import SwiftUI
import UserNotifications

/// Asks for the daily reminder after a good moment (a finished round, a solved crossword word, a
/// finished game) instead of during onboarding, where a cold system prompt is mostly declined.
/// Our own card comes first; the system prompt only opens when the learner says yes to it.
enum ReminderAsk {
    /// At most this many asks, a few days apart.
    static let maxAsks = 2
    static let daysBetween: TimeInterval = 3 * 24 * 3600
    private static let countKey = "reminderAsk.count"
    private static let lastKey = "reminderAsk.last"

    /// True while iOS has never asked and our card hasn't been shown too often or too recently.
    static func shouldAsk(now: Date = .now) async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .notDetermined else { return false }
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: countKey) < maxAsks else { return false }
        if let last = defaults.object(forKey: lastKey) as? Date, now.timeIntervalSince(last) < daysBetween { return false }
        return true
    }

    static func noteAsked(now: Date = .now) {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        defaults.set(now, forKey: lastKey)
    }
}

/// The card after a good moment: a time, "Hatırlat" (then the system prompt) or "Şimdi değil".
struct ReminderAskSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var time = Calendar.current.date(from: DateComponents(hour: 20, minute: 30)) ?? .now
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 52, height: 52)
                .background(Palette.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text("Güzel bir tur oldu")
                    .font(KelimeFont.english(30, relativeTo: .title))
                Text("Yarın da aynı saatte 2 dakikalık bir tur hatırlatalım mı? Günde bir bildirim, başka bir şey yok.")
                    .font(KelimeFont.ui(15, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text("Saat").font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
                Spacer()
                DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "tr_TR"))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
            Button {
                Task { await allow() }
            } label: {
                if asking { ProgressView().tint(Palette.onAccent) } else { Text("Hatırlat") }
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))
            .disabled(asking)
            Button("Şimdi değil") {
                Analytics.signal("reminder.ask", ["result": "later"])
                dismiss()
            }
            .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .screenBackground()
        .presentationDetents([.height(470)])
        .onAppear { ReminderAsk.noteAsked() }
    }

    private func allow() async {
        asking = true
        let granted = await Reminder.requestAuthorization()
        if granted {
            let c = Calendar.current.dateComponents([.hour, .minute], from: time)
            let minutes = (c.hour ?? 20) * 60 + (c.minute ?? 30)
            await Reminder.schedule(minutes: minutes)
            await model.setSetting(.reminderTime, String(minutes))
        }
        Analytics.signal("reminder.ask", ["result": granted ? "granted" : "denied"])
        dismiss()
    }
}
