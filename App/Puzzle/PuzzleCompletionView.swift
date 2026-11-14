import KelimeCore
import KelimeUI
import SwiftUI

struct PuzzleCompletionView: View {
    let model: PuzzleModel
    /// The free game to suggest (Günün Bulmacası only).
    var nextGame: GameKind?
    let onDone: () -> Void
    var onNext: (GameKind) -> Void = { _ in }
    let onRestart: () -> Void
    @State private var sharing = false

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
                if let nextGame {
                    Button("Devam et: \(nextGame.title)") { onNext(nextGame) }
                        .buttonStyle(PrimaryButtonStyle(height: 52))
                    Button("Sonucu paylaş") { sharing = true }
                        .buttonStyle(OutlineButtonStyle())
                } else {
                    Button("Sonucu paylaş") { sharing = true }
                        .buttonStyle(PrimaryButtonStyle(height: 52))
                }
                HStack {
                    Button("Yeniden çöz", action: onRestart)
                    Spacer()
                    Button("Kapat", action: onDone)
                        .fontWeight(.semibold)
                }
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
                .frame(minHeight: 44)
                if model.isDaily {
                    Text("Yarın yeni bulmaca seni bekliyor.")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 24)
            .askForReview(when: true)
            .sheet(isPresented: $sharing) {
                ShareImageSheet(title: "Bulmaca sonucu", name: model.title) { style in
                    PuzzleShareCard(game: game, title: model.title, time: model.timeText, style: style)
                }
            }
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

/// The finished crossword as a 9:16 share image: spoiler-free grid, time and hints.
struct PuzzleShareCard: View {
    let game: CrosswordGame
    let title: String
    let time: String
    let style: ShareCardStyle

    var body: some View {
        let puzzle = game.puzzle
        let cell = min(26, 288 / CGFloat(max(puzzle.width, 1)) - 3)
        ShareFrame(style: style) {
            Spacer().frame(height: 30)
            Text(title.uppercased(with: Locale(identifier: "tr_TR")))
                .font(KelimeFont.ui(14, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.ink2)
            Text(TurkishDate.header(.now))
                .font(KelimeFont.ui(15))
                .foregroundStyle(Palette.ink2)
                .padding(.top, 2)
            Text("\(puzzle.entries.count) kelime")
                .font(KelimeFont.english(64))
                .tracking(-1.5)
                .padding(.top, 20)
            Text("\(time) · \(game.hintsUsed) ipucu")
                .font(KelimeFont.ui(20, weight: .semibold))
            ShareGrid(game: game, cell: cell)
                .frame(maxWidth: .infinity)
                .padding(.top, 34)
        }
    }
}

