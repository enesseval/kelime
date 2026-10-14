import KelimeCore
import KelimeUI
import SwiftUI

struct PuzzleCompletionView: View {
    let model: PuzzleModel
    let onDone: () -> Void

    var body: some View {
        if let game = model.game {
            VStack(alignment: .leading, spacing: 22) {
                Text("BULMACA TAMAM")
                    .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                    .tracking(1)
                    .foregroundStyle(Palette.ink2)
                Text("\(game.puzzle.entries.count) kelime,\n\(max(1, Int((Double(model.seconds) / 60).rounded()))) dakika.")
                    .font(KelimeFont.english(52, relativeTo: .largeTitle))
                    .tracking(-1)
                HStack(spacing: 24) {
                    stat(model.timeText, "süre")
                    stat("\(game.hintsUsed)", "ipucu")
                }
                if !model.helpedWords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Widget'ına eklenen kelimeler").font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                        FlowLayout(spacing: 6) {
                            ForEach(model.helpedWords, id: \.id) { card in
                                Text(card.word)
                                    .font(KelimeFont.english(18, relativeTo: .body))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Palette.amberBackground, in: Capsule())
                            }
                        }
                    }
                }
                ShareGrid(game: game, cell: 14)
                Spacer()
                if let image = PuzzleShareRenderer.image(game: game, title: model.title, time: model.timeText) {
                    ShareLink(item: image, preview: SharePreview(model.title, image: image)) {
                        Text("Sonucu paylaş")
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                }
                Button(model.isDaily ? "Yarın yeni bulmaca" : "Kapat", action: onDone)
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 24)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(KelimeFont.ui(20, weight: .bold, relativeTo: .title3)).foregroundStyle(Palette.ink)
            Text(label).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Spoiler-free result: the grid shape, green for words solved alone, amber for words with help.
struct ShareGrid: View {
    let game: CrosswordGame
    let cell: CGFloat

    var body: some View {
        let puzzle = game.puzzle
        let helpedCells = Set(puzzle.entries.filter { game.helped.contains($0.id) }.flatMap(\.cells))
        let open = Set(puzzle.solution.keys)
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<puzzle.height, id: \.self) { row in
                GridRow {
                    ForEach(0..<puzzle.width, id: \.self) { col in
                        let p = GridPoint(row, col)
                        RoundedRectangle(cornerRadius: cell * 0.2)
                            .fill(!open.contains(p) ? Color.clear : helpedCells.contains(p) ? Palette.amber : Palette.green)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

enum PuzzleShareRenderer {
    @MainActor
    static func image(game: CrosswordGame, title: String, time: String) -> Image? {
        let view = VStack(alignment: .leading, spacing: 18) {
            Text(title).font(KelimeFont.ui(22, weight: .semibold))
            ShareGrid(game: game, cell: 22)
            Text("\(game.puzzle.entries.count) kelime · \(time) · \(game.hintsUsed) ipucu")
                .font(KelimeFont.ui(16))
                .foregroundStyle(Palette.ink2)
            Text(AppDisplayName.value).font(KelimeFont.ui(13, weight: .semibold)).foregroundStyle(Palette.ink2)
        }
        .foregroundStyle(Palette.ink)
        .padding(32)
        .background(Palette.paper)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
