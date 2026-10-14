import KelimeCore
import KelimeUI
import SwiftUI

/// The 5 widget themes on sample wallpapers. Paper is free; Pro themes open the paywall.
struct ThemePickerView: View {
    @Environment(AppModel.self) private var app
    @State private var wallpaper: Wallpaper = .light
    @State private var prefs: Preferences?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duvar kağıdını değiştir")
                        .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                    SegmentedPicker(options: Wallpaper.allCases, selection: $wallpaper) { $0.label }
                }
                ForEach(WidgetThemeID.allCases) { theme in
                    themeCard(theme)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("Tema")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: app.dataVersion) {
            prefs = await app.read { db in try Preferences.load(db) }
        }
    }

    private func themeCard(_ theme: WidgetThemeID) -> some View {
        let locked = theme.isPro && !(prefs?.isPro ?? false)
        let selected = prefs?.effectiveTheme == theme
        var entry = SampleContent.snapshot(SampleContent.reluctant, state: .struggling)
        entry.theme = theme
        return Button {
            if locked {
                app.router.showPaywall(.theme)
            } else {
                Task { await app.updatePreferences { $0.theme = theme } }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(theme.name).font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                    Spacer()
                    if locked { ProBadge() }
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent).font(.system(size: 20))
                    }
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(wallpaper.homeBackground)
                    VStack(spacing: 12) {
                        RectangularWidgetView(entry: entry)
                            .padding(10)
                            .frame(width: 172, height: 76)
                            // iOS dims the wallpaper behind lock-screen widgets; mimic that so
                            // white text stays readable on the light wallpaper too.
                            .background(.black.opacity(wallpaper == .light ? 0.32 : 0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)
                        MediumCardWidgetView(entry: entry)
                            .padding(16)
                            .frame(width: 300, height: 150)
                            .background(theme.colors.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .themeColorScheme(theme)
                            .allowsHitTesting(false)
                    }
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? Palette.accent : Palette.line, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(theme.name) teması\(locked ? ", Pro" : "")\(selected ? ", seçili" : "")"))
    }
}
