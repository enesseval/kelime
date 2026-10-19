import KelimeCore
import KelimeUI
import SwiftUI

/// Six onboarding steps. No paywall here: Pro options are shown but can't be picked.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app

    enum Step: Int, CaseIterable {
        case welcome, goal, level, rhythm, widget, reminder
    }

    @State private var step: Step = .welcome
    @State private var choices = OnboardingChoices()
    @State private var examDate = Calendar.current.date(byAdding: .month, value: 2, to: .now) ?? .now
    @State private var examUnknown = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 30)) ?? .now
    @State private var finishing = false

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome { topBar }
            Group {
                switch step {
                case .welcome: welcome
                case .goal: goal
                case .level: level
                case .rhythm: rhythm
                case .widget: widgetGuide
                case .reminder: reminder
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        }
        .screenBackground()
        .animation(.snappy, value: step)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button { go(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Geri")
            Spacer()
            HStack(spacing: 6) {
                ForEach(Step.allCases.dropFirst(), id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Palette.accent : Palette.surface2)
                        .frame(width: s == step ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Adım \(step.rawValue) / 5"))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 8)
    }

    private func go(_ delta: Int) {
        if let next = Step(rawValue: step.rawValue + delta) { step = next }
    }

    private func page<Content: View, Footer: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(KelimeFont.english(36, relativeTo: .largeTitle))
                        .tracking(-0.7)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink2)
                    }
                    content()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 8) { footer() }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - 1 Welcome

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)
            LockScreenMockup(entry: SampleContent.snapshot(SampleContent.reluctant, state: .struggling))
                .frame(height: 300)
            VStack(spacing: 10) {
                Text("Telefonuna her baktığında bir kelime.")
                    .font(KelimeFont.english(34, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                Text("Kelimeyi sadece oyunda öğrenmiyorsun; gün boyu kilit ekranında karşına çıkıyor.")
                    .font(KelimeFont.ui(15, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            Spacer()
            Button("Başla") { go(1) }
                .buttonStyle(PrimaryButtonStyle(height: 54))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - 2 Goal

    private var goal: some View {
        page(title: "Neden İngilizce?") {
            VStack(spacing: 10) {
                ForEach(LearningGoal.allCases) { option in
                    OptionRow(title: option.label, selected: choices.goal == option) { choices.goal = option }
                }
            }
            if choices.goal == .yds {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sınav tarihin?").font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                    DatePicker("Sınav tarihi", selection: $examDate, in: Date.now..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                        .disabled(examUnknown)
                        .opacity(examUnknown ? 0.4 : 1)
                    Toggle("Henüz belli değil", isOn: $examUnknown)
                        .font(KelimeFont.ui(15, relativeTo: .body))
                        .tint(Palette.accent)
                }
                .surfaceCard(radius: 18, padding: 16)
            }
        } footer: {
            Button("Devam") {
                choices.examDate = choices.goal == .yds && !examUnknown ? LocalDate(examDate, calendar: .current) : nil
                go(1)
            }
            .buttonStyle(PrimaryButtonStyle(height: 54))
        }
    }

    // MARK: - 3 Level

    private var level: some View {
        page(title: "Seviyen hangisi?", subtitle: "Örnek kelimelere bakıp seç. Sonra Ayarlar'dan değiştirebilirsin.") {
            VStack(spacing: 10) {
                ForEach(CEFRLevel.allCases, id: \.self) { level in
                    Button { choices.level = level } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(level.rawValue).font(KelimeFont.english(28, relativeTo: .title))
                            Text(LevelSamples.words(for: level).joined(separator: ", "))
                                .font(KelimeFont.english(18, relativeTo: .body, italic: true))
                                .foregroundStyle(Palette.ink2)
                            Spacer()
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 64)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(choices.level == level ? Palette.accent : Palette.line, lineWidth: choices.level == level ? 2 : 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(choices.level == level ? .isSelected : [])
                }
            }
            Button("Emin değilim, ortadan başlat") {
                choices.level = .b1
                go(1)
            }
            .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(Palette.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
        } footer: {
            Button("Devam") { go(1) }.buttonStyle(PrimaryButtonStyle(height: 54))
        }
    }

    // MARK: - 4 Rhythm

    private var rhythm: some View {
        page(title: "Kelime ne sıklıkla değişsin?") {
            RhythmPreview(rotation: choices.rotation)
            VStack(spacing: 10) {
                ForEach(RotationInterval.allCases, id: \.self) { interval in
                    OptionRow(
                        title: interval.label,
                        selected: choices.rotation == interval,
                        badge: interval.isPro ? "PRO" : nil,
                        disabled: interval.isPro
                    ) { choices.rotation = interval }
                }
            }
        } footer: {
            Button("Devam") { go(1) }.buttonStyle(PrimaryButtonStyle(height: 54))
        }
    }

    // MARK: - 5 Widget guide

    private var widgetGuide: some View {
        page(title: "Widget'ı ekle", subtitle: "En önemli adım bu: kelimeler kilit ekranında görünsün. 30 saniye sürer.") {
            WidgetGuideSteps()
        } footer: {
            Button("Ekledim") { go(1) }.buttonStyle(PrimaryButtonStyle(height: 54))
            Button("Sonra") { go(1) }
                .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    // MARK: - 6 Reminder

    private var reminder: some View {
        page(title: "Günde bir hatırlatma: tekrar zamanı", subtitle: "İstersen her gün aynı saatte kısa bir tekrar hatırlatalım.") {
            DatePicker("Saat", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "tr_TR"))
                .frame(maxWidth: .infinity)
        } footer: {
            Button {
                Task {
                    finishing = true
                    let granted = await Reminder.requestAuthorization()
                    let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                    choices.reminderMinutes = granted ? (c.hour ?? 20) * 60 + (c.minute ?? 30) : nil
                    await app.completeOnboarding(choices)
                }
            } label: {
                if finishing { ProgressView().tint(Palette.onAccent) } else { Text("İzin ver") }
            }
            .buttonStyle(PrimaryButtonStyle(height: 54))
            .disabled(finishing)
            Button("Gerek yok") {
                Task {
                    finishing = true
                    choices.reminderMinutes = nil
                    await app.completeOnboarding(choices)
                }
            }
            .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(finishing)
        }
    }
}

extension RotationInterval {
    /// Turkish label: 30 dk / 1 saat / 3 saat / Günde bir.
    var label: String {
        switch self {
        case .thirtyMinutes: "30 dk"
        case .oneHour: "1 saat"
        case .threeHours: "3 saat"
        case .daily: "Günde bir"
        }
    }

    /// How many different words a day this rhythm shows.
    var wordsPerDay: Int { 24 * 60 / minutes }
}

/// Selectable row with an optional badge, used across onboarding and settings.
struct OptionRow: View {
    let title: String
    let selected: Bool
    var badge: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(KelimeFont.ui(17, weight: .medium, relativeTo: .body))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(KelimeFont.ui(11, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.accent)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 56)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Palette.accent : Palette.line, lineWidth: selected ? 2 : 1))
            .opacity(disabled ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A phone lock screen with the rectangular widget, for onboarding and the theme picker.
struct LockScreenMockup: View {
    let entry: WidgetSnapshot
    var wallpaper: Wallpaper = .dark

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 40, style: .continuous).fill(wallpaper.background)
            VStack(spacing: 4) {
                Text(TurkishDate.header(.now))
                    .font(KelimeFont.ui(14, weight: .semibold))
                    .opacity(0.85)
                Text("9:41")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .opacity(0.92)
                RectangularWidgetView(entry: entry)
                    .padding(10)
                    .frame(width: 172, height: 76)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 10)
            }
            .foregroundStyle(.white)
            .padding(.top, 34)
        }
        .frame(maxWidth: 260)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Kilit ekranında \(entry.card?.word ?? "") kelimesi"))
    }
}

/// Sample wallpapers for the previews: light photo, dark photo, solid color.
enum Wallpaper: String, CaseIterable, Identifiable {
    case light, dark, solid
    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Açık"
        case .dark: "Koyu"
        case .solid: "Düz renk"
        }
    }

    var background: LinearGradient {
        switch self {
        case .light:
            LinearGradient(colors: [Color(light: 0xC9B79C, dark: 0xC9B79C), Color(light: 0x7E9AA8, dark: 0x7E9AA8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark:
            LinearGradient(colors: [Color(light: 0x2A2E33, dark: 0x2A2E33), Color(light: 0x14171B, dark: 0x14171B)], startPoint: .top, endPoint: .bottom)
        case .solid:
            LinearGradient(colors: [Color(light: 0x5B6C8F, dark: 0x5B6C8F)], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Home-screen backdrop behind home widgets.
    var homeBackground: LinearGradient {
        switch self {
        case .light:
            LinearGradient(colors: [Color(light: 0xE4DCCD, dark: 0xE4DCCD), Color(light: 0xCBD6DC, dark: 0xCBD6DC)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark, .solid:
            background
        }
    }
}

/// Live preview of the onboarding rhythm step: the lock-screen card cycles through words.
struct RhythmPreview: View {
    let rotation: RotationInterval
    @State private var index = 0
    private let cards = [SampleContent.reluctant, SampleContent.reliable, SampleContent.hesitate, SampleContent.significant]

    var body: some View {
        VStack(spacing: 10) {
            RectangularWidgetView(entry: SampleContent.snapshot(cards[index % cards.count], state: .new))
                .padding(10)
                .frame(width: 200, height: 84)
                .background(Wallpaper.dark.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .foregroundStyle(.white)
                .id(index)
                .transition(.opacity)
            Text("Günde \(rotation.wordsPerDay) farklı kelime")
                .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .task(id: rotation) {
            // Faster rhythms flip faster in the preview.
            let seconds = max(0.6, Double(rotation.minutes) / 180 * 1.6)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                withAnimation(.easeInOut(duration: 0.3)) { index += 1 }
            }
        }
    }
}
