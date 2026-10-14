import KelimeCore
import SwiftUI

/// CEFR level chip, e.g. "B1".
public struct LevelChip: View {
    public var level: CEFRLevel
    public var size: CGFloat

    public init(_ level: CEFRLevel, size: CGFloat = 11) {
        self.level = level
        self.size = size
    }

    public var body: some View {
        Text(level.rawValue)
            .font(KelimeFont.ui(size, weight: .semibold))
            .foregroundStyle(Palette.ink2)
            .padding(.vertical, size * 0.27)
            .padding(.horizontal, size * 0.55)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: size * 0.45, style: .continuous))
            .accessibilityLabel(Text("Seviye \(level.rawValue)"))
    }
}
