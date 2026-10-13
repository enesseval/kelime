import SwiftUI
import KelimeCore

/// Color tokens from `design/App.dc.html` (light and dark), shared by the app and the widget.
/// The design specifies OKLCH; values here are their sRGB equivalents.
public enum Palette {
    public static let background = Color(light: 0xF4F1EB, dark: 0x121110)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x1C1B19)
    public static let surface2 = Color(light: 0xEAE6DE, dark: 0x2A2825)
    /// Widget/card paper surface.
    public static let paper = Color(light: 0xFBF9F5, dark: 0x1C1B19)
    public static let ink = Color(light: 0x1B1916, dark: 0xF2EEE7)
    public static let ink2 = Color(light: 0x6A6359, dark: 0xA39C91)
    public static let line = Color(light: 0x1B1916, dark: 0xF2EEE7).opacity(0.11)

    public static let accent = Color(light: 0x335AA6, dark: 0x8BB1F7)
    public static let accentSoft = Color(light: 0xE2ECFD, dark: 0x1B2942)
    public static let onAccent = Color(light: 0xFFFFFF, dark: 0x121110)

    /// Zorlanılan. Never red.
    public static let amber = Color(light: 0xE49839, dark: 0xEEAC53)
    public static let amberBackground = Color(light: 0xFFECCD, dark: 0x442A08)
    public static let amberInk = Color(light: 0x915114, dark: 0xFBC77C)

    /// Öğrenildi.
    public static let green = Color(light: 0x50986B, dark: 0x75BE8F)
    public static let greenBackground = Color(light: 0xE0F5E6, dark: 0x1A3123)
    public static let greenInk = Color(light: 0x285F3F, dark: 0xA1DBB4)

    /// Dot color for a learning state in full-color rendering.
    public static func stateColor(_ state: LearningState) -> Color {
        switch state {
        case .new: ink2
        case .struggling: amber
        case .learned: green
        }
    }
}

extension Color {
    /// A color that resolves to `light` or `dark` hex RGB with the color scheme.
    public init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
import UIKit

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#else
import AppKit

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
