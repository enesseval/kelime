import KelimeCore
import KelimeUI
import SwiftUI

/// Four onboarding steps: welcome, level, the widget and a daily reminder.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app

    enum Step: Int, CaseIterable {
        case welcome, level, widget, reminder
    }

    @State private var step: Step = .welcome
    @State private var choices = OnboardingChoices(level: .a1)
    /// Levels with units; the others are shown as coming soon.
    @State private var levels: [CEFRLevel] = [.a1]
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 30)) ?? .now
    @State private var finishing = false

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome { topBar }
            Group {
                switch step {
                case .welcome: welcome
                case .level: level
                case .widget: widgetGuide
                case .reminder: reminder
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        }
        .screenBackground()
        .animation(.snappy, value: step)
        .task {
            levels = await app.read { db in try Curriculum.levels(db: db) } ?? [.a1]
            if !levels.contains(choices.level), let first = levels.first { choices.level = first }
        }
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
            .accessibilityLabel(Text("Adım \(step.rawValue) / \(Step.allCases.count - 1)"))
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
            LockScreenMockup(entry: SampleContent.snapshot(SampleContent.happy, state: .struggling))
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

    // MARK: - 2 Level

    private var level: some View {
        page(title: "Seviyen hangisi?", subtitle: "Bölümler seviye seviye hazırlanıyor. Hazır olanlardan başla; sıradaki seviye gelince bitirdiğin yerden geçersin.") {
            VStack(spacing: 10) {
                ForEach(CEFRLevel.allCases, id: \.self) { level in
                    let available = levels.contains(level)
                    Button { choices.level = level } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(level.rawValue).font(KelimeFont.english(28, relativeTo: .title))
                            Text(LevelSamples.words(for: level).joined(separator: ", "))
                                .font(KelimeFont.english(18, relativeTo: .body, italic: true))
                                .foregroundStyle(Palette.ink2)
                                .lineLimit(1)
                            Spacer()
                            if !available {
                                Text("Yakında")
                                    .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                                    .foregroundStyle(Palette.ink2)
                            }
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 64)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(choices.level == level ? Palette.accent : Palette.line, lineWidth: choices.level == level ? 2 : 1))
                        .contentShape(Rectangle())
                        .opacity(available ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                    .accessibilityAddTraits(choices.level == level ? .isSelected : [])
                }
            }
        } footer: {
            Button("Devam") { go(1) }.buttonStyle(PrimaryButtonStyle(height: 54))
        }
    }

    // MARK: - 3 Widget guide

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

    // MARK: - 4 Reminder

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
}

/// A phone lock screen with the rectangular widget, for onboarding.
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
