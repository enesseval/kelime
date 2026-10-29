import KelimeUI
import SwiftUI
import UIKit

/// Profil › Uygulama ikonu: the default cream icon or one of the alternates in the asset
/// catalog (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case standard
    case blue
    case orange

    var id: String { rawValue }

    /// The alternate icon name, nil for the primary icon.
    var iconName: String? {
        switch self {
        case .standard: nil
        case .blue: "AppIcon-Blue"
        case .orange: "AppIcon-Orange"
        }
    }

    var label: String {
        switch self {
        case .standard: "Krem"
        case .blue: "Mavi"
        case .orange: "Turuncu"
        }
    }

    var background: Color {
        switch self {
        case .standard: Color(red: 0.957, green: 0.945, blue: 0.922)
        case .blue: Color(red: 0.2, green: 0.353, blue: 0.651)
        case .orange: Color(red: 0.894, green: 0.596, blue: 0.224)
        }
    }

    var ink: Color {
        self == .blue ? Color(red: 0.957, green: 0.945, blue: 0.922) : Color(red: 0.106, green: 0.098, blue: 0.086)
    }

    @MainActor static var current: AppIconChoice {
        allCases.first { $0.iconName == UIApplication.shared.alternateIconName } ?? .standard
    }
}

struct AppIconRow: View {
    @State private var selected = AppIconChoice.current

    var body: some View {
        HStack(spacing: 12) {
            Text("Uygulama ikonu").font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink)
            Spacer()
            ForEach(AppIconChoice.allCases) { choice in
                Button { choose(choice) } label: {
                    Text("k")
                        .font(KelimeFont.english(22))
                        .foregroundStyle(choice.ink)
                        .frame(width: 36, height: 36)
                        .background(choice.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.line))
                        .padding(3)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.accent, lineWidth: selected == choice ? 2 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.label)
                .accessibilityAddTraits(selected == choice ? .isSelected : [])
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
    }

    private func choose(_ choice: AppIconChoice) {
        guard choice != selected, UIApplication.shared.supportsAlternateIcons else { return }
        selected = choice
        UIApplication.shared.setAlternateIconName(choice.iconName) { error in
            if error != nil { Task { @MainActor in selected = AppIconChoice.current } }
        }
    }
}
