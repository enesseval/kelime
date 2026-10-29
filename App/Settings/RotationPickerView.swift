import KelimeCore
import KelimeUI
import SwiftUI

/// Ayarlar › Değişim sıklığı: how often the widget shows a new word. Normal is free, the faster
/// ones are Pro. No exact interval is promised: iOS decides when a widget really reloads.
struct RotationPickerView: View {
    @Environment(AppModel.self) private var app
    @State private var selected: RotationInterval = .default
    @State private var storedPro = false

    /// Pro as the purchase knows it now, or as the database cached it.
    private var isPro: Bool { app.isPro || storedPro }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Kilit ekranındaki kelimenin ne sıklıkla yenileneceğini seç. Widget'ın ne zaman yenileneceğine iOS karar verir; kelime bazen birkaç dakika geç değişebilir.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .padding(.bottom, 4)
                ForEach(RotationInterval.choices, id: \.self) { interval in
                    row(interval)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("Değişim sıklığı")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: app.dataVersion) {
            let prefs = await app.read { db in try Preferences.load(db) }
            storedPro = prefs?.isPro ?? false
            selected = prefs.map { $0.isPro || app.isPro ? $0.rotationInterval : .default } ?? .default
        }
    }

    private func row(_ interval: RotationInterval) -> some View {
        let locked = interval.needsPro && !isPro
        let isSelected = selected == interval && !locked
        return Button {
            if locked {
                app.router.showPaywall(.rotation)
                return
            }
            selected = interval
            Task { await app.updatePreferences { $0.rotationInterval = interval } }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: interval.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 40, height: 40)
                    .background(Palette.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(interval.label).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                    Text(interval.detail)
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.accent)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isSelected ? Palette.accent : Palette.line, lineWidth: isSelected ? 2 : 1))
            .proCornerTag(locked, radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension RotationInterval {
    var needsPro: Bool { self != .threeHours }

    /// "Günde 4'e kadar yeni kelime": an upper bound, never a promise.
    var detail: String {
        switch self {
        case .threeHours: "Günde 4'e kadar yeni kelime"
        case .oneHour: "Günde 12'ye kadar yeni kelime"
        case .thirtyMinutes: "Günde 24'e kadar yeni kelime"
        case .daily: "Günde bir yeni kelime"
        }
    }

    var symbol: String {
        switch self {
        case .threeHours: "sun.max"
        case .oneHour: "bolt"
        case .thirtyMinutes: "bolt.fill"
        case .daily: "calendar"
        }
    }
}
