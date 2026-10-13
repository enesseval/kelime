import SwiftUI
import KelimeCore

/// Word state shown by shape, so it reads in monochrome: ○ yeni · ◐ zorlanılan · ● öğrenildi.
public struct StateDot: View {
    public var state: LearningState
    public var size: CGFloat
    /// nil uses the full-color state color; pass a color (e.g. `.white`) for monochrome rendering.
    public var color: Color?

    public init(_ state: LearningState, size: CGFloat = 10, color: Color? = nil) {
        self.state = state
        self.size = size
        self.color = color
    }

    public var body: some View {
        let tint = color ?? Palette.stateColor(state)
        let stroke = max(1.5, size * 0.16)
        ZStack {
            switch state {
            case .new:
                Circle().strokeBorder(tint, lineWidth: stroke)
            case .struggling:
                Circle().strokeBorder(tint, lineWidth: stroke)
                Circle().fill(tint).mask(alignment: .leading) {
                    Rectangle().frame(width: size / 2)
                }
            case .learned:
                Circle().fill(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(state.label))
    }
}

extension LearningState {
    /// Turkish label: Yeni / Zorlanılan / Öğrenildi.
    public var label: String {
        switch self {
        case .new: "Yeni"
        case .struggling: "Zorlanılan"
        case .learned: "Öğrenildi"
        }
    }
}
