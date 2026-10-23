import KelimeUI
import SwiftUI

/// The opening film of onboarding: at dawn a phone wakes with a word, the day passes over the
/// sky with a new word at every glance, and at night the words of the day turn learned. Plays
/// on its own (about 13 seconds); a tap moves to the next scene and "Atla" skips to the end.
/// Drawn in code, no video. With Reduce Motion the scenes change with plain fades.
struct CinematicIntro: View {
    let onFinish: () -> Void

    enum Scene: Int, CaseIterable {
        case wake, day, learned
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: Scene = .wake
    @State private var hour: Double = 6.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                OnboardingSky(hour: hour)
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        if scene != .learned {
                            Button("Atla") { scene = .learned }
                                .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(minWidth: 44, minHeight: 44)
                                .padding(.horizontal, 12)
                        }
                    }
                    .frame(height: 44)
                    Group {
                        switch scene {
                        case .wake: WakeScene(reduceMotion: reduceMotion, phoneHeight: phoneHeight(geo), hour: $hour)
                        case .day: DayScene(reduceMotion: reduceMotion, phoneHeight: phoneHeight(geo), hour: $hour)
                        case .learned: LearnedScene(reduceMotion: reduceMotion, hour: $hour, onStart: onFinish)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // The old scene is gone before the new one fades in, so captions never overlap.
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.5).delay(0.3)),
                        removal: .opacity.animation(.easeOut(duration: 0.25))
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
            case .day: 5.6
            case .learned: 0
            }
            guard seconds > 0 else { return }
            try? await Task.sleep(for: .seconds(seconds))
            advance()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    /// The phone takes most of the screen, leaving room for the caption.
    private func phoneHeight(_ geo: GeometryProxy) -> CGFloat {
        min(600, geo.size.height * 0.62)
    }

    private func advance() {
        guard let next = Scene(rawValue: scene.rawValue + 1) else { return }
        scene = next
    }
}

// MARK: - Scene 1: the phone wakes at dawn

private struct WakeScene: View {
    let reduceMotion: Bool
    let phoneHeight: CGFloat
    @Binding var hour: Double
    @State private var phoneOn = false
    @State private var typed = 0
    @State private var meaning = false
    @State private var caption = false

    private let word = "serendipity"

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            LockScreenPhone(hour: hour, time: "07:00", word: String(word.prefix(typed)), meaning: meaning ? "mutlu tesadüf" : "", lit: phoneOn, height: phoneHeight)
                .scaleEffect(phoneOn || reduceMotion ? 1 : 0.9)
                .rotation3DEffect(.degrees(phoneOn || reduceMotion ? 0 : 14), axis: (x: 1, y: 0, z: 0))
                .opacity(phoneOn || reduceMotion ? 1 : 0)
            Text("Telefonuna her baktığında…")
                .font(KelimeFont.english(32, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 8)
                .opacity(caption ? 1 : 0)
                .offset(y: caption || reduceMotion ? 0 : 12)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.impact(weight: .light), trigger: phoneOn)
        .task {
            withAnimation(.easeInOut(duration: 2.5)) { hour = 7.2 }
            withAnimation(.spring(response: reduceMotion ? 0.2 : 1.0, dampingFraction: 0.85)) { phoneOn = true }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 1.0))
            if reduceMotion {
                typed = word.count
            } else {
                for count in 1...word.count {
                    typed = count
                    try? await Task.sleep(for: .milliseconds(70))
                }
            }
            withAnimation(.easeOut(duration: 0.5)) { meaning = true }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.8)) { caption = true }
        }
    }
}

// MARK: - Scene 2: a day of glances

private struct DayScene: View {
    let reduceMotion: Bool
    let phoneHeight: CGFloat
    @Binding var hour: Double
    @State private var index = 0
    @State private var caption = false

    private let glances: [(hour: Double, time: String, word: String, meaning: String)] = [
        (9, "09:00", "journey", "yolculuk"),
        (13, "13:00", "curious", "meraklı"),
        (18.3, "18:20", "brave", "cesur"),
        (22.5, "22:30", "dream", "hayal"),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            let glance = glances[index]
            LockScreenPhone(hour: hour, time: glance.time, word: glance.word, meaning: glance.meaning, height: phoneHeight)
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.45), value: index)
            VStack(spacing: 8) {
                Text("…bir kelime.")
                    .font(KelimeFont.english(32, relativeTo: .largeTitle))
                Text("Günde 4'e kadar yeni kelime, hiç uğraşmadan.")
                    .font(KelimeFont.ui(16, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .multilineTextAlignment(.center)
            .opacity(caption ? 1 : 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.selection, trigger: index)
        .task {
            withAnimation(.easeOut(duration: 0.8)) { caption = true }
            withAnimation(.easeInOut(duration: 1.1)) { hour = glances[0].hour }
            for next in 1..<glances.count {
                try? await Task.sleep(for: .milliseconds(1250))
                withAnimation(.easeInOut(duration: reduceMotion ? 0.3 : 1.1)) { hour = glances[next].hour }
                index = next
            }
        }
    }
}

// MARK: - Scene 3: the words of the day are learned

private struct LearnedScene: View {
    let reduceMotion: Bool
    @Binding var hour: Double
    let onStart: () -> Void
    @State private var dropped = 0
    @State private var learned = false
    @State private var title = false

    private let words = ["serendipity", "journey", "curious", "brave", "dream", "kind"]

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 0)
            CenteredFlow(spacing: 10) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    chip(word, learned: learned && index != 2)
                        .opacity(index < dropped ? 1 : 0)
                        .offset(y: index < dropped || reduceMotion ? 0 : -80)
                        .rotationEffect(.degrees(index < dropped || reduceMotion ? 0 : Double(index % 2 == 0 ? -10 : 10)))
                }
            }
            .frame(maxWidth: 330)
            VStack(spacing: 12) {
                Text("Kelime Widget")
                    .font(KelimeFont.english(46, relativeTo: .largeTitle))
                    .tracking(-0.8)
                Text("Kilit ekranında öğren. Oyunla pekiştir.")
                    .font(KelimeFont.ui(17, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.8))
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
            withAnimation(.easeInOut(duration: 1)) { hour = 23 }
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
        .foregroundStyle(learned ? Color(red: 0.6, green: 0.9, blue: 0.7) : .white.opacity(0.9))
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(learned ? Color(red: 0.2, green: 0.5, blue: 0.34).opacity(0.6) : .white.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(learned ? 0 : 0.22)))
    }
}

/// Rows of chips, each row centred.
private struct CenteredFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.midX - row.width / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: [Int] = [], rowWidth: CGFloat = 0, rowHeight: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.isEmpty && rowWidth + spacing + size.width > width {
                rows.append((current, rowWidth, rowHeight))
                current = []; rowWidth = 0; rowHeight = 0
            }
            rowWidth += (current.isEmpty ? 0 : spacing) + size.width
            rowHeight = max(rowHeight, size.height)
            current.append(index)
        }
        if !current.isEmpty { rows.append((current, rowWidth, rowHeight)) }
        return rows
    }
}

// MARK: - Lock screen

/// The lock screen on the drawn phone: date, time and the rectangular widget.
struct LockScreenPhone<Overlay: View>: View {
    var hour: Double
    let time: String
    let word: String
    let meaning: String
    var lit = true
    /// False shows an empty widget slot (the widget is not added yet).
    var widget = true
    var height: CGFloat = 560
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        let scale = height / 560
        DevicePhone(hour: hour, height: height) {
            ZStack(alignment: .top) {
                VStack(spacing: 2) {
                    Text(TurkishDate.header(.now))
                        .font(KelimeFont.ui(15 * scale, weight: .semibold))
                        .opacity(0.85)
                    Text(time)
                        .font(.system(size: 78 * scale, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Group {
                        if widget {
                            VStack(alignment: .leading, spacing: 2 * scale) {
                                Text(word.isEmpty ? " " : word)
                                    .font(KelimeFont.english(25 * scale))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .contentTransition(.opacity)
                                Text(meaning.isEmpty ? " " : meaning)
                                    .font(KelimeFont.ui(14 * scale))
                                    .opacity(meaning.isEmpty ? 0 : 0.8)
                            }
                            .frame(width: 190 * scale, alignment: .leading)
                            .padding(12 * scale)
                            .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 20 * scale, style: .continuous))
                            .environment(\.colorScheme, .dark)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        } else {
                            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                                .strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .frame(width: 214 * scale, height: 68 * scale)
                        }
                    }
                    .padding(.top, 12 * scale)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6)
                .padding(.top, 64 * scale)
                overlay()
            }
            .opacity(lit ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(word.isEmpty ? "Kilit ekranı" : "Kilit ekranında \(word) kelimesi: \(meaning)"))
    }
}

extension LockScreenPhone where Overlay == EmptyView {
    init(hour: Double, time: String, word: String, meaning: String, lit: Bool = true, widget: Bool = true, height: CGFloat = 560) {
        self.init(hour: hour, time: time, word: word, meaning: meaning, lit: lit, widget: widget, height: height) { EmptyView() }
    }
}

// MARK: - Widget guide animation

/// Onboarding's widget step: the lock-screen steps played on the phone, in a loop, with the
/// current step written under it.
struct WidgetAddAnimation: View {
    var height: CGFloat = 470
    @State private var step = 0

    static let steps = [
        "Kilit ekranına basılı tut",
        "Özelleştir › Kilit Ekranı'na dokun",
        "Widget ekle'ye dokun, Kelime Widget'ı seç",
        "Hazır: kelimeler kilit ekranında",
    ]

    var body: some View {
        VStack(spacing: 18) {
            LockScreenPhone(hour: 21, time: "21:00", word: "serendipity", meaning: "mutlu tesadüf", widget: step == 3, height: height) {
                ZStack(alignment: .bottom) {
                    Color.clear
                    if step == 0 {
                        TouchDot(pressing: true).frame(maxHeight: .infinity)
                    }
                    if step == 1 {
                        Text("Özelleştir")
                            .font(KelimeFont.ui(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 40)
                            .background(.white.opacity(0.25), in: Capsule())
                            .overlay(TouchDot(pressing: false).offset(x: 34, y: 6))
                            .padding(.bottom, height * 0.1)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if step == 2 {
                        WidgetGallerySheet()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .scaleEffect(step == 1 || step == 2 ? 0.96 : 1)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(step + 1)")
                    .font(KelimeFont.ui(15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 28, height: 28)
                    .background(step == 3 ? Palette.green : Palette.accent, in: Circle())
                Text(Self.steps[step])
                    .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            // One step's caption replaces the other; they never show together.
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .frame(minHeight: 46)
            .padding(14)
            .clipped()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Reminder preview

/// Onboarding's reminder step: the daily notification dropping onto the lock screen at the
/// chosen time; the sky follows that hour.
struct ReminderPreview: View {
    let time: Date
    var height: CGFloat = 400
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = Double(c.hour ?? 20) + Double(c.minute ?? 0) / 60
        LockScreenPhone(hour: hour, time: time.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)), word: "", meaning: "", widget: false, height: height) {
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
            .frame(width: height * 0.4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(.top, height * 0.47)
            .offset(y: shown || reduceMotion ? 0 : -40)
            .opacity(shown ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.8), value: hour)
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
