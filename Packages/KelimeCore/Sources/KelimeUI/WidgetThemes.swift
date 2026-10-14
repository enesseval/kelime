import KelimeCore
import SwiftUI

/// Colors and word font of a home-screen widget theme.
public struct WidgetColors: Sendable {
    public var background: Color
    public var ink: Color
    public var ink2: Color
    public var chip: Color
    /// Color of the English word (the theme's one accent, if any).
    public var word: Color
    /// Mono sets words in the UI sans instead of the serif.
    public var sansWords: Bool
}

extension WidgetThemeID {
    public var colors: WidgetColors {
        switch self {
        case .paper:
            WidgetColors(background: Palette.paper, ink: Palette.ink, ink2: Palette.ink2, chip: Palette.surface2, word: Palette.ink, sansWords: false)
        case .ink:
            WidgetColors(
                background: Color(light: 0x000000, dark: 0x000000),
                ink: Color(light: 0xFFFFFF, dark: 0xFFFFFF),
                ink2: Color(light: 0x9B958C, dark: 0x9B958C),
                chip: Color(light: 0x1F1E1C, dark: 0x1F1E1C),
                word: Color(light: 0xFFFFFF, dark: 0xFFFFFF),
                sansWords: false
            )
        case .glass:
            WidgetColors(
                background: Color(light: 0xDCE4EC, dark: 0x27303A),
                ink: Color(light: 0x13202D, dark: 0xEEF3F8),
                ink2: Color(light: 0x5A6A7B, dark: 0xA8B5C3),
                chip: Color(light: 0xC9D3DE, dark: 0x36414D),
                word: Color(light: 0x13202D, dark: 0xEEF3F8),
                sansWords: false
            )
        case .ember:
            WidgetColors(
                background: Color(light: 0x2B1B15, dark: 0x2B1B15),
                ink: Color(light: 0xF7EBE2, dark: 0xF7EBE2),
                ink2: Color(light: 0xC6A999, dark: 0xC6A999),
                chip: Color(light: 0x3E2A21, dark: 0x3E2A21),
                word: Color(light: 0xF29155, dark: 0xF29155),
                sansWords: false
            )
        case .mono:
            WidgetColors(
                background: Color(light: 0xFFFFFF, dark: 0x0B0B0B),
                ink: Color(light: 0x0B0B0B, dark: 0xFFFFFF),
                ink2: Color(light: 0x6B6B6B, dark: 0x9A9A9A),
                chip: Color(light: 0xEDEDED, dark: 0x222222),
                word: Color(light: 0x0B0B0B, dark: 0xFFFFFF),
                sansWords: true
            )
        }
    }

    /// Ink and Ember are always dark, so state colors use their dark variants.
    public var forcedColorScheme: ColorScheme? {
        switch self {
        case .ink, .ember: .dark
        default: nil
        }
    }

    /// The English word font for this theme.
    public func wordFont(_ size: CGFloat) -> Font {
        colors.sansWords ? KelimeFont.ui(size * 0.92, weight: .bold) : KelimeFont.english(size)
    }
}

extension View {
    /// Applies a theme's fixed color scheme, if it has one.
    @ViewBuilder
    public func themeColorScheme(_ theme: WidgetThemeID) -> some View {
        if let scheme = theme.forcedColorScheme {
            environment(\.colorScheme, scheme)
        } else {
            self
        }
    }
}
