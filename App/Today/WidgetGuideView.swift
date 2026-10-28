import KelimeUI
import SwiftUI

/// Numbered steps for adding the widget, with Kilit ekranı / Ana ekran tabs.
struct WidgetGuideSteps: View {
    enum Place: String, CaseIterable {
        case lock = "Kilit ekranı"
        case home = "Ana ekran"

        var steps: [String] {
            switch self {
            case .lock:
                ["Kilit ekranına basılı tut", "Özelleştir › Kilit Ekranı'na dokun", "Widget ekle'ye dokun", "Listeden Kilit Kelime'yi seç"]
            case .home:
                ["Ana ekranda boş bir yere basılı tut", "Sol üstteki Düzenle › Widget ekle'ye dokun", "Kilit Kelime'yi ara", "Boyut seç ve Widget ekle'ye dokun"]
            }
        }
    }

    @State private var place: Place = .lock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SegmentedPicker(options: Place.allCases, selection: $place) { $0.rawValue }
            ForEach(Array(place.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(index + 1)")
                        .font(KelimeFont.ui(15, weight: .bold, relativeTo: .body))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 28, height: 28)
                        .background(Palette.accent, in: Circle())
                    Text(step).font(KelimeFont.ui(16, relativeTo: .body))
                }
                .surfaceCard(radius: 16, padding: 14)
            }
        }
    }
}

/// "Widget nasıl eklenir?" sheet, from the Bugün banner and Ayarlar.
struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                WidgetGuideSteps()
                Spacer()
                Button("Ekledim") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .screenBackground()
            .navigationTitle("Widget nasıl eklenir?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sonra") { dismiss() }.tint(Palette.accent)
                }
            }
        }
    }
}
