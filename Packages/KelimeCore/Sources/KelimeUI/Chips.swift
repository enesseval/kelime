import KelimeCore
import SwiftUI

/// CEFR level chip, e.g. "B1".
public struct LevelChip: View {
    public var level: CEFRLevel
    public var size: CGFloat
    public var foreground: Color
    public var background: Color

    public init(_ level: CEFRLevel, size: CGFloat = 11, foreground: Color = Palette.ink2, background: Color = Palette.surface2) {
        self.level = level
        self.size = size
        self.foreground = foreground
        self.background = background
    }

    public var body: some View {
        Text(level.rawValue)
            .font(KelimeFont.ui(size, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, size * 0.27)
            .padding(.horizontal, size * 0.55)
            .background(background, in: RoundedRectangle(cornerRadius: size * 0.45, style: .continuous))
            .accessibilityLabel(Text("Seviye \(level.rawValue)"))
    }
}

/// Learning-state pill: Yeni / Zorlanılan / Öğrenildi.
public struct StateChip: View {
    public var state: LearningState
    public var size: CGFloat

    public init(_ state: LearningState, size: CGFloat = 11) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        Text(state.label)
            .font(KelimeFont.ui(size, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, size * 0.36)
            .padding(.horizontal, size * 0.75)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch state {
        case .new: Palette.ink2
        case .struggling: Palette.amberInk
        case .learned: Palette.greenInk
        }
    }

    private var background: Color {
        switch state {
        case .new: Palette.surface2
        case .struggling: Palette.amberBackground
        case .learned: Palette.greenBackground
        }
    }
}

/// Small uppercase "PRO" badge for locked items.
public struct ProBadge: View {
    public init() {}

    public var body: some View {
        Text("PRO")
            .font(KelimeFont.ui(11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Palette.ink2)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// "PRO" tucked into the top-right corner of a locked card, cut by the card's own corner.
public struct ProCornerTag: ViewModifier {
    let show: Bool
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content.overlay {
            if show {
                ZStack(alignment: .topTrailing) {
                    Color.clear
                    Text("PRO")
                        .font(KelimeFont.ui(10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Palette.onAccent)
                        .padding(.leading, 9)
                        .padding(.trailing, 8)
                        .padding(.vertical, 4)
                        .background(Palette.accent, in: UnevenRoundedRectangle(bottomLeadingRadius: 8, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityLabel("Pro")
            }
        }
    }
}

extension View {
    /// Marks a card as Pro with a tag in its top-right corner. `radius` is the card's corner.
    public func proCornerTag(_ show: Bool = true, radius: CGFloat) -> some View {
        modifier(ProCornerTag(show: show, radius: radius))
    }
}
