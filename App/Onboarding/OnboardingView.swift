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
    /// Level cards come in one after another.
    @State private var levelsShown = false
    @State private var showHomeSteps = false

    var body: some View {
        ZStack {
            // The film draws its own sky; the steps after it keep one that follows the evening.
            if step != .welcome {
                OnboardingSky(hour: skyHour).animation(.easeInOut(duration: 1), value: skyHour)
            }
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
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .animation(.snappy, value: step)
        .task {
            #if DEBUG
            // Screenshots of one step: launch with `-onboardingStep widget` (Debug only).
            if let name = UserDefaults.standard.string(forKey: "onboardingStep"),
               let start = Step.allCases.first(where: { "\($0)" == name }) {
                step = start
            }
            #endif
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

    /// The sky of each step: dusk while choosing, night for the widget, and the reminder's own
    /// hour on the reminder step.
    private var skyHour: Double {
        switch step {
        case .welcome, .level: return 18.6
        case .widget: return 21
        case .reminder:
            let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            return Double(c.hour ?? 20) + Double(c.minute ?? 0) / 60
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(KelimeFont.english(36, relativeTo: .largeTitle))
                    .tracking(-0.7)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(.white.opacity(0.75))
                }
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        // The buttons sit in the bottom inset: the content scrolls above them, never under.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) { footer() }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.75), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        }
    }

    /// A step that fits the screen without scrolling: `content` gets the height left between the
    /// title and the buttons, so the phone can size itself to it.
    private func fittedPage<Content: View, Footer: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping (CGFloat) -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(KelimeFont.english(32, relativeTo: .largeTitle))
                .tracking(-0.6)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(.white.opacity(0.75))
            }
            GeometryReader { geo in
                content(geo.size.height)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            HStack(spacing: 12) { footer() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - 1 Welcome

    private var welcome: some View {
        CinematicIntro { go(1) }
    }

    // MARK: - 2 Level

    private var level: some View {
        page(title: "Seviyen hangisi?", subtitle: "Bölümler seviye seviye hazırlanıyor. Hazır olanlardan başla; sıradaki seviye gelince bitirdiğin yerden geçersin.") {
            VStack(spacing: 10) {
                ForEach(Array(CEFRLevel.allCases.enumerated()), id: \.element) { index, level in
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
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(choices.level == level ? Palette.accent : Palette.line, lineWidth: choices.level == level ? 2 : 1))
                        .contentShape(Rectangle())
                        .opacity(available ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                    .accessibilityAddTraits(choices.level == level ? .isSelected : [])
                    .opacity(levelsShown ? 1 : 0)
                    .offset(y: levelsShown ? 0 : 24)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double(index) * 0.07), value: levelsShown)
                }
            }
            .onAppear { levelsShown = true }
        } footer: {
            Button("Devam") { go(1) }.buttonStyle(PrimaryButtonStyle(height: 54))
        }
    }

    // MARK: - 3 Widget guide

    private var widgetGuide: some View {
        fittedPage(title: "Widget'ı ekle", subtitle: "En önemli adım bu: kelimeler kilit ekranında görünsün. 30 saniye sürer.") { height in
            VStack(spacing: 10) {
                // The step caption (about 74 pt) and the home-screen link (44 pt) take the rest.
                WidgetAddAnimation(height: max(240, height - 128))
                Button("Ana ekrana eklemek için") { showHomeSteps = true }
                    .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: 44)
            }
        } footer: {
            Button("Sonra") { go(1) }.buttonStyle(GlassButtonStyle())
            Button("Ekledim") { go(1) }.buttonStyle(PrimaryButtonStyle(height: 54))
        }
        .sheet(isPresented: $showHomeSteps) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ana ekrana ekle").font(KelimeFont.english(28, relativeTo: .title))
                ForEach(Array(WidgetGuideSteps.Place.home.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)").font(KelimeFont.ui(16, relativeTo: .body))
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presentationDetents([.height(300)])
        }
    }

    // MARK: - 4 Reminder

    private var reminder: some View {
        fittedPage(title: "Günde bir hatırlatma", subtitle: "İstersen her gün aynı saatte kısa bir tekrar hatırlatalım.") { height in
            VStack(spacing: 14) {
                ReminderPreview(time: reminderTime, height: max(240, height - 70))
                HStack {
                    Text("Saat").font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body)).foregroundStyle(.white)
                    Spacer()
                    DatePicker("Saat", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        } footer: {
            Button("Gerek yok") {
                Task {
                    finishing = true
                    choices.reminderMinutes = nil
                    await app.completeOnboarding(choices)
                }
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(finishing)
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
        }
    }
}

extension RotationInterval {
    /// Turkish label. No exact interval is promised: iOS decides when a widget really reloads.
    var label: String {
        switch self {
        case .thirtyMinutes: "Çok sık"
        case .oneHour: "Sık"
        case .threeHours: "Normal"
        case .daily: "Günde bir"
        }
    }

    /// The choices in Ayarlar: normal is free, the faster ones are Pro.
    static let choices: [RotationInterval] = [.threeHours, .oneHour, .thirtyMinutes]
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

/// The secondary onboarding button, next to the primary one: glass on the sky.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}
