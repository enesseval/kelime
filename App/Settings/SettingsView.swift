import KelimeCore
import KelimeUI
import SwiftUI

struct SettingsData: Sendable {
    var prefs: Preferences
    var goal: LearningGoal
    var examDate: LocalDate?
    var reminderMinutes: Int?
    var speechRate: Float

    static func load(db: Database) throws -> SettingsData {
        SettingsData(
            prefs: try Preferences.load(db),
            goal: try Settings.string(.goal, in: db).flatMap(LearningGoal.init(rawValue:)) ?? .general,
            examDate: try Settings.date(.examDate, in: db),
            reminderMinutes: try Settings.int(.reminderTime, in: db),
            speechRate: try Settings.string(.speechRate, in: db).flatMap(Float.init) ?? 0.9
        )
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @State private var data: SettingsData?
    @State private var showGuide = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(title: "Ayarlar")
                if let data {
                    levelSection(data)
                    widgetSection(data)
                    reminderSection(data)
                    proSection
                    about
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .hiddenNavigationBar()
        .task(id: app.dataVersion) {
            data = await app.read { db in try SettingsData.load(db: db) }
        }
        .sheet(isPresented: $showGuide) { WidgetGuideView() }
        .toast($toast)
    }

    // MARK: - Sections

    private func levelSection(_ data: SettingsData) -> some View {
        SettingsSection("SEVİYE VE HEDEF") {
            SettingsRow("Seviye") {
                Menu {
                    ForEach([CEFRLevel.a2, .b1, .b2, .c1], id: \.self) { level in
                        Button(level.rawValue) { Task { await setLevel(level) } }
                    }
                } label: { valueLabel(data.prefs.level.rawValue) }
            }
            Divider().overlay(Palette.line)
            SettingsRow("Hedef") {
                Menu {
                    ForEach(LearningGoal.allCases) { goal in
                        Button(goal.label) { Task { await app.setSetting(.goal, goal.rawValue) } }
                    }
                } label: { valueLabel(data.goal.label) }
            }
            if data.goal == .yds {
                Divider().overlay(Palette.line)
                SettingsRow("Sınav tarihi") {
                    DatePicker("", selection: Binding(
                        get: { data.examDate?.startDate(in: .current) ?? .now },
                        set: { date in Task { await app.setSetting(.examDate, LocalDate(date, calendar: .current).string) } }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                }
            }
        }
    }

    private func widgetSection(_ data: SettingsData) -> some View {
        SettingsSection("WIDGET") {
            SettingsRow("Değişim sıklığı") {
                Menu {
                    ForEach(RotationInterval.allCases, id: \.self) { interval in
                        Button(interval.isPro && !data.prefs.isPro ? "\(interval.label) · Pro" : interval.label) {
                            if interval.isPro && !data.prefs.isPro {
                                app.router.showPaywall(.rotation)
                            } else {
                                Task { await app.updatePreferences { $0.rotationInterval = interval } }
                            }
                        }
                    }
                } label: { valueLabel(data.prefs.effectiveRotation.label) }
            }
            Divider().overlay(Palette.line)
            VStack(alignment: .leading, spacing: 10) {
                Text("Görünüm modu").font(KelimeFont.ui(15, relativeTo: .body))
                SegmentedPicker(options: WidgetMode.allCases, selection: Binding(
                    get: { data.prefs.defaultWidgetMode },
                    set: { mode in Task { await app.updatePreferences { $0.defaultWidgetMode = mode } } }
                )) { $0.label }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider().overlay(Palette.line)
            NavigationLink(value: Route.themePicker) {
                SettingsRowLabel("Tema", value: data.prefs.effectiveTheme.name)
            }
            .buttonStyle(.plain)
            Divider().overlay(Palette.line)
            Button { showGuide = true } label: {
                Text("Widget nasıl eklenir?")
                    .font(KelimeFont.ui(15, relativeTo: .body))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func reminderSection(_ data: SettingsData) -> some View {
        SettingsSection("HATIRLATMA VE TELAFFUZ") {
            SettingsRow("Günlük hatırlatma") {
                Toggle("", isOn: Binding(
                    get: { data.reminderMinutes != nil },
                    set: { on in Task { await setReminder(on ? (data.reminderMinutes ?? 20 * 60 + 30) : nil) } }
                ))
                .labelsHidden()
                .tint(Palette.green)
            }
            if let minutes = data.reminderMinutes {
                Divider().overlay(Palette.line)
                SettingsRow("Saat") {
                    DatePicker("", selection: Binding(
                        get: { Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? .now },
                        set: { date in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            Task { await setReminder((c.hour ?? 20) * 60 + (c.minute ?? 30)) }
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                }
            }
            Divider().overlay(Palette.line)
            SettingsRow("Ses ve hız") {
                Menu {
                    ForEach([Float(0.8), 0.9, 1.0], id: \.self) { rate in
                        Button(String(format: "%.1f×", rate)) {
                            Task { await app.setSetting(.speechRate, String(rate)) }
                            Speaker.shared.rateMultiplier = rate
                            Speaker.shared.speak("reluctant")
                        }
                    }
                } label: { valueLabel(String(format: "en-US · %.1f×", data.speechRate)) }
            }
        }
    }

    private var proSection: some View {
        SettingsSection("PRO") {
            Button { app.router.showPaywall(.base) } label: {
                SettingsRowLabel("Mevcut plan", value: app.purchases.planLabel)
            }
            .buttonStyle(.plain)
            .disabled(app.purchases.isPro)
            Divider().overlay(Palette.line)
            Button {
                Task {
                    let restored = await app.purchases.restore()
                    toast = restored ? "Pro geri yüklendi" : (app.purchases.lastError ?? "Geri yüklenecek satın alma bulunamadı")
                }
            } label: {
                Text("Satın alımları geri yükle")
                    .font(KelimeFont.ui(15, relativeTo: .body))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kelime listesi: New General Service List, CC BY-SA 4.0")
            Text("İçerik yapay zekâ ile üretildi ve kontrol edildi")
            HStack(spacing: 6) {
                Button("Gizlilik") { openURL(Legal.privacyURL) }
                Text("·")
                Button("Koşullar") { openURL(Legal.termsURL) }
            }
            Text("\(AppDisplayName.value) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .padding(.top, 6)
        }
        .font(KelimeFont.ui(12, relativeTo: .caption))
        .foregroundStyle(Palette.ink2)
        .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func setLevel(_ level: CEFRLevel) async {
        await app.updatePreferences { prefs in
            prefs.level = level
            if let deck = DeckID.allCases.first(where: { $0.level == level }), !prefs.enabledDecks.contains(deck) {
                prefs.enabledDecks.append(deck)
            }
        }
    }

    private func setReminder(_ minutes: Int?) async {
        if let minutes {
            var allowed = await Reminder.isAuthorized()
            if !allowed { allowed = await Reminder.requestAuthorization() }
            guard allowed else {
                toast = "Bildirim izni Ayarlar'dan açılabilir"
                return
            }
            await Reminder.schedule(minutes: minutes)
            await app.setSetting(.reminderTime, String(minutes))
        } else {
            Reminder.cancel()
            await app.setSetting(.reminderTime, nil)
        }
    }

    private func valueLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
        }
        .font(KelimeFont.ui(15, relativeTo: .body))
        .foregroundStyle(Palette.ink2)
        .frame(minHeight: 44)
    }
}

/// Grouped card with an uppercase caption, as in the design.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                .tracking(0.7)
                .foregroundStyle(Palette.ink2)
                .padding(.leading, 4)
            VStack(spacing: 0) { content }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line))
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink)
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}

struct SettingsRowLabel: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink)
            Spacer()
            Text("\(value) ›").font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}
