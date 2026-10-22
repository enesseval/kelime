import KelimeCore
import KelimeUI
import SwiftUI

/// The Tümü filters: level, state and kind of word.
struct WordFilterSheet: View {
    @Binding var filter: WordFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("SEVİYE", options: CEFRLevel.allCases, selection: $filter.levels) { $0.rawValue }
                    group("DURUM", options: LearningState.allCases, selection: $filter.states) { $0.filterLabel }
                    group("TÜR", options: WordKind.allCases, selection: $filter.kinds) { $0.label }
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Temizle") { filter = WordFilter() }.disabled(filter.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func group<Option: Hashable>(
        _ title: String,
        options: [Option],
        selection: Binding<Set<Option>>,
        label: @escaping (Option) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                .tracking(0.7)
                .foregroundStyle(Palette.ink2)
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let on = selection.wrappedValue.contains(option)
                    Button {
                        if on { selection.wrappedValue.remove(option) } else { selection.wrappedValue.insert(option) }
                    } label: {
                        FilterChip(title: label(option), on: on)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// The filters in use, above the Tümü list; tapping one removes it.
struct ActiveFilters: View {
    @Binding var filter: WordFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filter.levels.sorted(), id: \.self) { level in
                    chip(level.rawValue) { filter.levels.remove(level) }
                }
                ForEach(LearningState.allCases.filter(filter.states.contains), id: \.self) { state in
                    chip(state.filterLabel) { filter.states.remove(state) }
                }
                ForEach(WordKind.allCases.filter(filter.kinds.contains), id: \.self) { kind in
                    chip(kind.label) { filter.kinds.remove(kind) }
                }
                Button("Temizle") { filter = WordFilter() }
                    .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 5) {
                Text(title)
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Palette.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filtresini kaldır")
    }
}

struct FilterChip: View {
    let title: String
    let on: Bool

    var body: some View {
        Text(title)
            .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(on ? Palette.onAccent : Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(on ? Palette.accent : Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(on ? Color.clear : Palette.line))
    }
}

/// The A–Z strip on the right edge: drag or tap a letter to jump to its first word.
struct LetterIndex: View {
    let items: [WordItem]
    let jump: (String) -> Void
    @State private var current: String?

    /// First word id for each starting letter, in list order.
    private var anchors: [(letter: String, id: String)] {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for item in items {
            guard let first = item.card.word.first else { continue }
            let letter = first.isLetter ? String(first).uppercased() : "#"
            if seen.insert(letter).inserted { result.append((letter, item.id)) }
        }
        return result
    }

    var body: some View {
        let anchors = anchors
        VStack(spacing: 1) {
            ForEach(anchors, id: \.letter) { anchor in
                Text(anchor.letter)
                    .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(current == anchor.letter ? Palette.accent : Palette.ink2)
                    .frame(width: 18, height: 15)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let index = min(max(Int((value.location.y - 6) / 16), 0), anchors.count - 1)
                    guard anchors.indices.contains(index), anchors[index].letter != current else { return }
                    current = anchors[index].letter
                    jump(anchors[index].id)
                }
                .onEnded { _ in current = nil }
        )
        .sensoryFeedback(.selection, trigger: current)
        .padding(.trailing, 2)
        .accessibilityHidden(true)
    }
}

extension LearningState {
    /// Label in the Tümü filter.
    var filterLabel: String {
        switch self {
        case .new: "Yeni"
        case .struggling: "Zorlanılan"
        case .learned: "Öğrenildi"
        }
    }
}
