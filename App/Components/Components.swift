import KelimeCore
import KelimeUI
import SwiftUI

extension View {
    /// White (dark: charcoal) card with a hairline border, as used across the app screens.
    func surfaceCard(radius: CGFloat = 22, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.line))
    }

    /// Page background and default text color.
    func screenBackground() -> some View {
        self
            .background(Palette.background.ignoresSafeArea())
            .foregroundStyle(Palette.ink)
            // Keeps scrolled content from showing through the status bar.
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    Palette.background
                        .frame(height: proxy.safeAreaInsets.top)
                        .offset(y: -proxy.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
            }
    }

    /// Liquid Glass on iOS 26 and later, for controls that float above the content
    /// (bottom action bars, toolbar pills, toasts). Earlier systems get `fallback`.
    @ViewBuilder
    func floatingGlass<S: Shape>(in shape: S, fallback: Color = Palette.surface) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(fallback, in: shape)
        }
    }

    /// Transient message at the bottom of the screen.
    func toast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                Text(text)
                    .font(KelimeFont.ui(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .floatingGlass(in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation { message.wrappedValue = nil }
                    }
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.spring(duration: 0.3), value: message.wrappedValue)
    }
}

/// Large screen title from the design (32 pt bold), with an optional kicker above it.
struct ScreenTitle: View {
    let title: String
    var kicker: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let kicker {
                Text(kicker)
                    .font(KelimeFont.ui(13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
            }
            Text(title)
                .font(KelimeFont.ui(32, weight: .bold, relativeTo: .largeTitle))
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// Filled accent button (Başla, Hızlı Tekrar …).
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Rectangle())
    }
}

/// Soft tinted button (Biliyorum / Zorlanıyorum, Devam et …).
struct TintedButtonStyle: ButtonStyle {
    var ink: Color = Palette.ink
    var background: Color = Palette.surface2
    var height: CGFloat = 44
    var fullWidth = true

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(KelimeFont.ui(fullWidth ? 16 : 14, weight: .semibold, relativeTo: .body))
            .foregroundStyle(ink)
            .padding(.horizontal, fullWidth ? 0 : 18)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .background(background, in: RoundedRectangle(cornerRadius: fullWidth ? 14 : 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

/// iOS-style segmented control drawn like the design (surface2 track, raised selection).
struct SegmentedPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selected ? Palette.ink : Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Palette.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// Small round progress bar (4 pt).
struct ThinProgressBar: View {
    var fraction: Double
    var color: Color = Palette.green

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surface2)
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityValue(Text("%\(Int(fraction * 100))"))
    }
}

/// Turkish dates for headers: "13 Ekim, Salı".
enum TurkishDate {
    static func header(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.setLocalizedDateFormatFromTemplate("d MMMM EEEE")
        let text = f.string(from: date)
        // "13 Ekim Salı" → "13 Ekim, Salı"
        guard let space = text.lastIndex(of: " ") else { return text }
        return text[..<space] + "," + text[space...]
    }
}

extension View {
    /// Hides the navigation bar on screens that draw their own large title. Uses the UIKit-backed
    /// modifier because `.toolbar(.hidden, for: .navigationBar)` left the bar's area swallowing
    /// taps at the top of the screen.
    func hiddenNavigationBar() -> some View {
        navigationBarHidden(true)
    }
}
