import SwiftUI

/// The three bundled typefaces. All cover ğ ş ı İ ç ö ü.
///
/// The font files live in `Fonts/` and are listed under `UIAppFonts` in both the app's and the
/// widget's Info.plist; without that, the widget silently falls back to the system font.
public enum KelimeFont {
    /// English words and sentences.
    public static let englishFamily = "Newsreader"
    /// Turkish text and UI.
    public static let uiFamily = "Hanken Grotesk"
    /// Self-test letter blanks.
    public static let monoFamily = "JetBrains Mono"

    /// English word or sentence at a fixed size (widgets).
    public static func english(_ size: CGFloat, italic: Bool = false) -> Font {
        let font = Font.custom(englishFamily, fixedSize: size)
        return italic ? font.italic() : font
    }

    /// English text that scales with Dynamic Type (app screens).
    public static func english(_ size: CGFloat, relativeTo style: Font.TextStyle, italic: Bool = false) -> Font {
        let font = Font.custom(englishFamily, size: size, relativeTo: style)
        return italic ? font.italic() : font
    }

    /// Turkish / UI text at a fixed size (widgets).
    public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(uiFamily, fixedSize: size).weight(weight)
    }

    /// Turkish / UI text that scales with Dynamic Type (app screens).
    public static func ui(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(uiFamily, size: size, relativeTo: style).weight(weight)
    }

    public static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.custom(monoFamily, fixedSize: size).weight(weight)
    }
}
