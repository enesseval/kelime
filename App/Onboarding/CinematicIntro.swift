import KelimeUI
import SwiftUI

/// The opening film of onboarding: a phone wakes with a word, a day passes with a new word at
/// every glance, and the words of the day turn learned. Plays on its own (about 13 seconds); a
/// tap moves to the next scene and "Atla" skips to the end. Drawn in code, no video. With
/// Reduce Motion the scenes change with plain fades.
struct CinematicIntro: View {
    let onFinish: () -> Void

    enum Scene: Int, CaseIterable {
        case wake, day, learned
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: Scene = .wake

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CinematicBackdrop(scene: scene)
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        if scene != .learned {
                            Button("Atla") { scene = .learned }
                                .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(minWidth: 44, minHeight: 44)
                                .padding(.horizontal, 12)
                        }
                    }
                    .frame(height: 44)
                    Group {
                        switch scene {
                        case .wake: WakeScene(reduceMotion: reduceMotion)
                        case .day: DayScene(reduceMotion: reduceMotion)
                        case .learned: LearnedScene(reduceMotion: reduceMotion, onStart: onFinish)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(min(1, geo.size.height / 760))
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.04)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    ))
                    .id(scene)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .animation(.easeInOut(duration: reduceMotion ? 0.3 : 0.7), value: scene)
        .task(id: scene) {
            // Each scene plays for its length, then the next one starts.
            let seconds: Double = switch scene {
            case .wake: 4.2
            case .day: 5.2
            case .learned: 0
            }
            guard seconds > 0 else { return }
            try? await Task.sleep(for: .seconds(seconds))
            advance()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private func advance() {
        guard let next = Scene(rawValue: scene.rawValue + 1) else { return }
        scene = next
    }
}

// MARK: - Backdrop

/// Night black, warming to a morning glow during the day scene.
private struct CinematicBackdrop: View {
    let scene: CinematicIntro.Scene

    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [glow.opacity(0.55), .clear],
                center: .init(x: 0.5, y: 0.38),
                startRadius: 10,
                endRadius: 420
            )
            .animation(.easeInOut(duration: 1.2), value: scene)
        }
        .ignoresSafeArea()
    }

    private var glow: Color {
        switch scene {
        case .wake: Color(red: 0.25, green: 0.33, blue: 0.62)
        case .day: Color(red: 0.95, green: 0.62, blue: 0.32)
        case .learned: Color(red: 0.22, green: 0.55, blue: 0.40)
        }
    }
}

// MARK: - Scene 1: the phone wakes

private struct WakeScene: View {
    let reduceMotion: Bool
    @State private var phoneOn = false
    @State private var typed = 0
    @State private var meaning = false
    @State private var caption = false

    private let word = "serendipity"

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 0)
            CinematicPhone(
                time: "08:00",
                word: String(word.prefix(typed)),
                meaning: meaning ? "mutlu tesadüf" : "",
                lit: phoneOn
            )
            .scaleEffect(phoneOn || reduceMotion ? 1 : 0.92)
            .opacity(phoneOn || reduceMotion ? 1 : 0.2)
            Text("Telefonuna her baktığında…")
                .font(KelimeFont.english(32, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .opacity(caption ? 1 : 0)
                .offset(y: caption || reduceMotion ? 0 : 12)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.impact(weight: .light), trigger: phoneOn)
        .task {
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.9)) { phoneOn = true }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.9))
            if reduceMotion {
                typed = word.count
            } else {
                for count in 1...word.count {
                    typed = count
                    try? await Task.sleep(for: .milliseconds(70))
                }
            }
            withAnimation(.easeOut(duration: 0.5)) { meaning = true }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.8)) { caption = true }
        }
    }
}

// MARK: - Scene 2: a day of glances

private struct DayScene: View {
    let reduceMotion: Bool
    @State private var index = 0
    @State private var caption = false

    private let glances: [(time: String, word: String, meaning: String)] = [
        ("08:00", "serendipity", "mutlu tesadüf"),
        ("12:30", "journey", "yolculuk"),
        ("18:15", "curious", "meraklı"),
        ("22:40", "brave", "cesur"),
    ]

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 0)
            let glance = glances[index]
            CinematicPhone(time: glance.time, word: glance.word, meaning: glance.meaning, lit: true)
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.45), value: index)
            VStack(spacing: 10) {
                Text("…bir kelime.")
                    .font(KelimeFont.english(32, relativeTo: .largeTitle))
                Text("Gün boyu, hiç uğraşmadan.")
                    .font(KelimeFont.ui(17, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .opacity(caption ? 1 : 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.selection, trigger: index)
        .task {
            withAnimation(.easeOut(duration: 0.8)) { caption = true }
            for next in 1..<glances.count {
                try? await Task.sleep(for: .milliseconds(1150))
                index = next
            }
        }
    }
}

// MARK: - Scene 3: the words of the day are learned

private struct LearnedScene: View {
    let reduceMotion: Bool
    let onStart: () -> Void
    @State private var dropped = 0
    @State private var learned = false
    @State private var title = false

    private let words = ["serendipity", "journey", "curious", "brave", "kind", "dream"]

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 0)
            FlowLayout(spacing: 10) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    chip(word, learned: learned && index != 2)
                        .opacity(index < dropped ? 1 : 0)
                        .offset(y: index < dropped || reduceMotion ? 0 : -60)
                        .rotationEffect(.degrees(index < dropped || reduceMotion ? 0 : Double(index % 2 == 0 ? -8 : 8)))
                }
            }
            .frame(maxWidth: 320)
            VStack(spacing: 12) {
                Text("Kelime Widget")
                    .font(KelimeFont.english(44, relativeTo: .largeTitle))
                    .tracking(-0.8)
                Text("Kilit ekranında öğren. Oyunla pekiştir.")
                    .font(KelimeFont.ui(17, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .opacity(title ? 1 : 0)
            .offset(y: title || reduceMotion ? 0 : 10)
            Spacer(minLength: 0)
            Button("Başla", action: onStart)
                .buttonStyle(PrimaryButtonStyle(height: 54))
                .opacity(title ? 1 : 0)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.success, trigger: learned)
        .task {
            for count in 1...words.count {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.62)) { dropped = count }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 140))
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeInOut(duration: 0.5)) { learned = true }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.8)) { title = true }
        }
    }

    private func chip(_ word: String, learned: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: learned ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 13, weight: .semibold))
            Text(word).font(KelimeFont.english(19, relativeTo: .body))
        }
        .foregroundStyle(learned ? Color(red: 0.55, green: 0.86, blue: 0.66) : .white.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(learned ? Color(red: 0.2, green: 0.45, blue: 0.32).opacity(0.55) : .white.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(learned ? 0 : 0.18)))
    }
}

// MARK: - Phone

/// A phone lock screen drawn for the film: time, date and the rectangular widget.
struct CinematicPhone: View {
    let time: String
    let word: String
    let meaning: String
    var lit = true
    /// False shows an empty widget slot (the widget is not added yet).
    var widget = true

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(LinearGradient(
                    colors: lit ? [Color(red: 0.16, green: 0.19, blue: 0.27), Color(red: 0.05, green: 0.06, blue: 0.09)] : [.black, .black],
                    startPoint: .top, endPoint: .bottom
                ))
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1.5)
            Capsule().fill(.black).frame(width: 82, height: 24).padding(.top, 12)
            VStack(spacing: 2) {
                Text(TurkishDate.header(.now))
                    .font(KelimeFont.ui(13, weight: .semibold))
                    .opacity(0.8)
                Text(time)
                    .font(.system(size: 66, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                if widget {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.isEmpty ? " " : word)
                        .font(KelimeFont.english(24, relativeTo: .title3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.opacity)
                    Text(meaning.isEmpty ? " " : meaning)
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .opacity(meaning.isEmpty ? 0 : 0.75)
                }
                .frame(width: 172, alignment: .leading)
                .padding(12)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 12)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: 196, height: 62)
                        .padding(.top, 12)
                }
            }
            .foregroundStyle(.white)
            .padding(.top, 52)
            .opacity(lit ? 1 : 0)
        }
        .frame(width: 236, height: 430)
        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Kilit ekranında \(word) kelimesi: \(meaning)"))
    }
}

// MARK: - Widget guide animation

/// Onboarding's widget step: the lock-screen steps played on a phone, in a loop, with the
/// current step written under it.
struct WidgetAddAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    static let steps = [
        "Kilit ekranına basılı tut",
        "Özelleştir › Kilit Ekranı'na dokun",
        "Widget ekle'ye dokun, Kelime Widget'ı seç",
        "Hazır: kelimeler kilit ekranında",
    ]

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottom) {
                CinematicPhone(time: "9:41", word: "serendipity", meaning: "mutlu tesadüf", widget: step == 3)
                    .scaleEffect(step == 1 || step == 2 ? 0.94 : 1)
                // 1: a long press on the lock screen.
                if step == 0 {
                    TouchDot(pressing: true).offset(y: -180)
                }
                // 2: the Özelleştir button.
                if step == 1 {
                    VStack(spacing: 10) {
                        Text("Özelleştir")
                            .font(KelimeFont.ui(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 40)
                            .background(.white.opacity(0.22), in: Capsule())
                            .overlay(TouchDot(pressing: false).offset(x: 34, y: 6))
                    }
                    .padding(.bottom, 46)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                // 3: the widget gallery with the Kelime widget.
                if step == 2 {
                    WidgetGallerySheet()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: 236, height: 430)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(step + 1)")
                    .font(KelimeFont.ui(15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 28, height: 28)
                    .background(step == 3 ? Palette.green : Palette.accent, in: Circle())
                Text(Self.steps[step])
                    .font(KelimeFont.ui(17, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(radius: 16, padding: 14)
            .accessibilityElement(children: .combine)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
        .sensoryFeedback(.selection, trigger: step)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(step == 3 ? 2.2 : 1.7))
                step = (step + 1) % Self.steps.count
            }
        }
    }
}

/// A finger on the screen: a soft circle, pulsing for a long press.
private struct TouchDot: View {
    let pressing: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.25)).frame(width: 56, height: 56).scaleEffect(pulse ? 1.25 : 0.85)
            Circle().fill(.white.opacity(0.9)).frame(width: 22, height: 22)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: pressing ? 0.6 : 0.4).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

/// The bottom sheet of the widget picker, with Kelime Widget chosen.
private struct WidgetGallerySheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(.secondary).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            Text("Widget ekle").font(KelimeFont.ui(15, weight: .semibold))
            HStack(spacing: 10) {
                ForEach(["Hava", "Kelime", "Pil"], id: \.self) { name in
                    let chosen = name == "Kelime"
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(chosen ? Palette.accent.opacity(0.9) : Color.gray.opacity(0.35))
                            .frame(height: 38)
                            .overlay {
                                if chosen {
                                    Text("Aa").font(KelimeFont.english(18)).foregroundStyle(Palette.onAccent)
                                }
                            }
                        Text(name).font(KelimeFont.ui(11, weight: chosen ? .semibold : .regular))
                    }
                    .overlay(alignment: .topTrailing) {
                        if chosen { TouchDot(pressing: false).scaleEffect(0.7).offset(x: 6, y: -6) }
                    }
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Reminder preview

/// Onboarding's reminder step: the daily notification dropping onto a lock screen at the
/// chosen time.
struct ReminderPreview: View {
    let time: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .top) {
            CinematicPhone(time: time.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)), word: "", meaning: "", widget: false)
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Palette.accent)
                    .frame(width: 30, height: 30)
                    .overlay(Text("Aa").font(KelimeFont.english(14)).foregroundStyle(Palette.onAccent))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("KELİME WIDGET").font(KelimeFont.ui(10, weight: .semibold)).opacity(0.7)
                        Spacer()
                        Text("şimdi").font(KelimeFont.ui(10)).opacity(0.6)
                    }
                    Text("Tekrar zamanı").font(KelimeFont.ui(13, weight: .semibold))
                    Text("2 dakikalık tur seni bekliyor.").font(KelimeFont.ui(12)).opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(width: 210)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 236)
            .offset(y: shown || reduceMotion ? 0 : -40)
            .opacity(shown ? 1 : 0)
        }
        .frame(width: 236, height: 430)
        .scaleEffect(0.8)
        .frame(height: 350)
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
        .task(id: time) {
            shown = false
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { shown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Örnek bildirim: Tekrar zamanı")
    }
}
