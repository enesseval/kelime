import KelimeCore
import KelimeUI
import SwiftUI

/// Picks how the lock-screen rectangular widget looks, with a live preview of each style.
/// Each widget can still override this from its own edit menu.
struct WidgetModePickerView: View {
    @Environment(AppModel.self) private var app
    @State private var selected: WidgetMode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Kilit ekranındaki dikdörtgen widget'ın nasıl görüneceğini seç. Her widget'ı ayrıca kendi düzenleme menüsünden değiştirebilirsin.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .padding(.bottom, 4)
                ForEach(WidgetMode.allCases, id: \.self) { mode in
                    row(mode)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("Kilit ekranı görünümü")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: app.dataVersion) {
            selected = await app.read { db in try Preferences.load(db).defaultWidgetMode }
        }
    }

    private func row(_ mode: WidgetMode) -> some View {
        let isSelected = selected == mode
        let entry = SampleContent.snapshot(SampleContent.reluctant, state: .struggling, mode: mode, phase: mode == .selfTest ? .question : .answer)
        return Button {
            selected = mode
            Task { await app.updatePreferences { $0.defaultWidgetMode = mode } }
        } label: {
            HStack(spacing: 14) {
                RectangularWidgetView(entry: entry)
                    .padding(mode == .dictionary ? 4 : 9)
                    .frame(width: 150, height: 68)
                    .background {
                        if mode != .dictionary {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.16))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Wallpaper.dark.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.label).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                    Text(mode.detail)
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Palette.accent : Palette.line)
            }
            .foregroundStyle(Palette.ink)
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isSelected ? Palette.accent : Palette.line, lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
