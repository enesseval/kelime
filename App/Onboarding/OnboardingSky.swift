import SwiftUI

/// The sky behind onboarding, drawn for an hour of the day: night, dawn, day or dusk, with the
/// sun moving along its arc, the moon and stars at night. Changing `hour` inside an animation
/// crossfades the sky and moves the sun.
struct OnboardingSky: View {
    var hour: Double
    /// Sun and moon; off on the phone's wallpaper, where they would sit on the clock.
    var celestial = true

    enum Phase: CaseIterable {
        case night, dawn, day, dusk

        init(hour: Double) {
            let h = hour.truncatingRemainder(dividingBy: 24)
            switch h {
            case 6..<9: self = .dawn
            case 9..<17: self = .day
            case 17..<20: self = .dusk
            default: self = .night
            }
        }

        var colors: [Color] {
            switch self {
            case .night: [Color(red: 0.03, green: 0.05, blue: 0.14), Color(red: 0.08, green: 0.09, blue: 0.22), Color(red: 0.14, green: 0.12, blue: 0.27)]
            case .dawn: [Color(red: 0.27, green: 0.33, blue: 0.62), Color(red: 0.80, green: 0.56, blue: 0.62), Color(red: 0.99, green: 0.74, blue: 0.55)]
            case .day: [Color(red: 0.18, green: 0.46, blue: 0.86), Color(red: 0.42, green: 0.68, blue: 0.95), Color(red: 0.74, green: 0.87, blue: 0.98)]
            case .dusk: [Color(red: 0.20, green: 0.16, blue: 0.40), Color(red: 0.74, green: 0.34, blue: 0.45), Color(red: 0.99, green: 0.60, blue: 0.32)]
            }
        }
    }

    var body: some View {
        let phase = Phase(hour: hour)
        GeometryReader { geo in
            ZStack {
                ForEach(Phase.allCases, id: \.self) { p in
                    LinearGradient(colors: p.colors, startPoint: .top, endPoint: .bottom)
                        .opacity(p == phase ? 1 : 0)
                }
                Stars(size: geo.size).opacity(phase == .night ? 1 : phase == .dusk ? 0.25 : 0)
                // The sun crosses the sky from 6:00 to 19:30, the moon stays up at night.
                let progress = min(max((hour - 6) / 13.5, 0), 1)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.95, blue: 0.75), Color(red: 1, green: 0.8, blue: 0.4).opacity(0)], center: .center, startRadius: 6, endRadius: 70))
                    .frame(width: 140, height: 140)
                    .position(
                        x: geo.size.width * (0.08 + 0.84 * progress),
                        y: geo.size.height * (0.42 - 0.32 * sin(.pi * progress))
                    )
                    .opacity(phase == .night || !celestial ? 0 : 1)
                Circle()
                    .fill(Color(red: 0.95, green: 0.94, blue: 0.86))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().fill(phase.colors[0]).frame(width: 30, height: 30).offset(x: 10, y: -6))
                    .shadow(color: .white.opacity(0.35), radius: 18)
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.12)
                    .opacity(phase == .night && celestial ? 1 : 0)
                // Soft horizon glow and a dark floor so white text stays readable.
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Fixed star field, the same on every launch.
private struct Stars: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvas in
            var rng = StarGenerator(seed: 7)
            for _ in 0..<70 {
                let x = Double(rng.next() % 1000) / 1000 * canvas.width
                let y = Double(rng.next() % 1000) / 1000 * canvas.height * 0.6
                let r = Double(rng.next() % 3 + 1) * 0.6
                let alpha = 0.35 + Double(rng.next() % 60) / 100
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(alpha)))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct StarGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
}

/// A phone drawn like the real device: titanium band, side buttons, Dynamic Island, and a
/// lock screen whose wallpaper follows the hour.
struct DevicePhone<Screen: View>: View {
    var hour: Double
    var height: CGFloat = 560
    @ViewBuilder var screen: () -> Screen

    static var aspect: CGFloat { 0.486 }

    var body: some View {
        let width = height * Self.aspect
        let radius = width * 0.17
        let bezel = width * 0.035
        ZStack {
            // Side buttons, behind the band.
            Group {
                Capsule().frame(width: 4, height: height * 0.05).offset(x: -width / 2 - 1, y: -height * 0.27)
                Capsule().frame(width: 4, height: height * 0.09).offset(x: -width / 2 - 1, y: -height * 0.16)
                Capsule().frame(width: 4, height: height * 0.09).offset(x: -width / 2 - 1, y: -height * 0.05)
                Capsule().frame(width: 4, height: height * 0.14).offset(x: width / 2 + 1, y: -height * 0.12)
            }
            .foregroundStyle(Color(white: 0.42))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.28), Color(white: 0.52), Color(white: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: radius - bezel * 0.4, style: .continuous)
                .fill(.black)
                .padding(bezel * 0.4)
            ZStack(alignment: .top) {
                OnboardingSky(hour: hour, celestial: false)
                    .overlay(Color.black.opacity(0.18))
                screen()
                Capsule().fill(.black).frame(width: width * 0.33, height: width * 0.095).padding(.top, width * 0.04)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius - bezel, style: .continuous))
            .padding(bezel)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.55), radius: 40, y: 24)
    }
}
