import KelimeCore
import KelimeUI
import SwiftUI

struct CrosswordView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: PuzzleModel
    @State private var showClues = false
    @State private var confirmRestart = false

    init(source: PuzzleSource) {
        _model = State(initialValue: PuzzleModel(source: source))
    }

    var body: some View {
        Group {
            if let game = model.game {
                if model.isComplete {
                    PuzzleCompletionView(model: model, onDone: close) { Task { await model.restart() } }
                } else {
                    playScreen(game)
                }
            } else if model.failed {
                ContentUnavailableView {
                    Label("Bulmaca hazırlanamadı", systemImage: "square.grid.3x3")
                } actions: {
                    Button("Kapat", action: close)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screenBackground()
        .task { await model.load(app: app) }
        .task(id: model.isComplete) {
            while !Task.isCancelled && !model.isComplete {
                try? await Task.sleep(for: .seconds(1))
                if scenePhase == .active { model.tick() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await model.save() } }
        }
        .onDisappear { Task { await model.save() } }
    }

    /// Closes through the router as well as `dismiss`, so the cover always goes away.
    private func close() {
        Task { await model.save() }
        app.router.puzzle = nil
        dismiss()
    }

    private func playScreen(_ game: CrosswordGame) -> some View {
        VStack(spacing: 0) {
            header
            toolbar
            CrosswordGrid(game: game) { model.select($0) }
                .padding(.horizontal, 16)
            Spacer(minLength: 8)
            clueBar(game)
            LetterKeyboard { model.type($0) } onDelete: { model.deleteBackward() }
        }
        .sheet(isPresented: $showClues) {
            ClueListSheet(game: game, clues: model.clues) { entry in
                model.focus(entry)
                showClues = false
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Kapat")
            Button { confirmRestart = true } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Baştan başla")
            Spacer()
            Text(model.title).font(KelimeFont.ui(15, weight: .semibold, relativeTo: .headline))
            Spacer()
            Text(model.timeText)
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .monospacedDigit()
                .frame(width: 88, alignment: .trailing)
                .accessibilityLabel("Süre \(model.timeText)")
        }
        .confirmationDialog("Bulmaca baştan başlasın mı?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Baştan başla", role: .destructive) { Task { await model.restart() } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Yazdığın harfler ve süre silinir.")
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            pill("Harf aç") { model.revealLetter() }
            pill("Kelimeyi kontrol et") { model.checkWord() }
            pill("Kelimeyi göster") { model.revealWord() }
        }
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .overlay(Capsule().strokeBorder(Palette.line))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func clueBar(_ game: CrosswordGame) -> some View {
        let entry = game.activeEntry
        let helped = game.helped.contains(entry.id)
        return HStack(spacing: 4) {
            Button { model.step(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 48)
            }
            .accessibilityLabel("Önceki ipucu")
            Button { showClues = true } label: {
                (Text("\(entry.number) \(entry.direction.label)").fontWeight(.semibold) + Text(" · ") + Text(model.clues[entry.id] ?? ""))
                    .font(KelimeFont.ui(15, relativeTo: .subheadline))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityHint("Tüm ipuçlarını açar")
            Button { model.step(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 48)
            }
            .accessibilityLabel("Sonraki ipucu")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 4)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(helped ? Palette.amber : .clear, lineWidth: 1.5))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

/// The crossword grid with every cell state from the design.
struct CrosswordGrid: View {
    let game: CrosswordGame
    let onTap: (GridPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let puzzle = game.puzzle
            let gap: CGFloat = 3
            let cell = min(40, (proxy.size.width - gap * CGFloat(puzzle.width - 1)) / CGFloat(puzzle.width))
            let solution = puzzle.solution
            let numbers = puzzle.numbers
            let active = Set(game.activeEntry.cells)
            VStack(spacing: gap) {
                ForEach(0..<puzzle.height, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<puzzle.width, id: \.self) { col in
                            let point = GridPoint(row, col)
                            if solution[point] != nil {
                                CrosswordCell(
                                    letter: game.typed[point],
                                    number: numbers[point],
                                    state: state(point, active: active),
                                    hinted: game.revealed.contains(point),
                                    size: cell
                                )
                                .onTapGesture { onTap(point) }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(point, number: numbers[point]))
                                .accessibilityAddTraits(.isButton)
                            } else {
                                Color.clear.frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(CGFloat(game.puzzle.width) / CGFloat(game.puzzle.height), contentMode: .fit)
        .frame(maxHeight: 400)
    }

    private func state(_ point: GridPoint, active: Set<GridPoint>) -> CrosswordCell.State {
        if point == game.cursor { return .cursor }
        if game.wrong.contains(point) { return .wrong }
        if active.contains(point) { return .activeWord }
        if game.puzzle.entries(at: point).contains(where: game.isSolved) { return .solved }
        return .normal
    }

    private func accessibilityLabel(_ point: GridPoint, number: Int?) -> String {
        let letter = game.typed[point].map(String.init) ?? "boş"
        let prefix = number.map { "\($0), " } ?? ""
        return "\(prefix)satır \(point.row + 1), sütun \(point.col + 1), \(letter)"
    }
}

struct CrosswordCell: View {
    enum State { case normal, cursor, activeWord, solved, wrong }

    let letter: Character?
    let number: Int?
    let state: State
    let hinted: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous).fill(background)
            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
                .strokeBorder(state == .wrong ? Palette.amber : Palette.line, lineWidth: state == .wrong ? 1.5 : 1)
                .opacity(state == .cursor ? 0 : 1)
            if let letter {
                Text(String(letter))
                    .font(KelimeFont.ui(size * 0.53, weight: .semibold))
                    .foregroundStyle(foreground)
            }
        }
        .overlay(alignment: .topLeading) {
            if let number {
                Text("\(number)")
                    .font(KelimeFont.ui(max(size * 0.25, 8), weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.7))
                    .padding(.leading, size * 0.11)
                    .padding(.top, 2)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if hinted {
                Circle().fill(Palette.amber).frame(width: 5, height: 5).padding(3)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.15), value: state)
    }

    private var background: Color {
        switch state {
        case .cursor: Palette.accent
        case .wrong: Palette.amberBackground
        case .activeWord: Palette.accentSoft
        case .solved: Palette.greenBackground
        case .normal: Palette.surface
        }
    }

    private var foreground: Color {
        switch state {
        case .cursor: Palette.onAccent
        case .wrong: Palette.amberInk
        case .solved: Palette.greenInk
        default: Palette.ink
        }
    }
}

/// Full clue list: Yatay and Dikey sections.
struct ClueListSheet: View {
    let game: CrosswordGame
    let clues: [String: String]
    let onPick: (CrosswordEntry) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("İpuçları")
                    .font(KelimeFont.ui(20, weight: .bold, relativeTo: .title3))
                    .padding(.bottom, 6)
                ForEach([CrosswordDirection.across, .down], id: \.self) { direction in
                    let entries = game.puzzle.orderedEntries.filter { $0.direction == direction }
                    if !entries.isEmpty {
                        Text(direction.label.uppercased(with: Locale(identifier: "tr_TR")))
                            .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                            .tracking(0.9)
                            .foregroundStyle(Palette.ink2)
                            .padding(.top, 10)
                        ForEach(entries) { entry in
                            Button { onPick(entry) } label: {
                                HStack(spacing: 10) {
                                    (Text("\(entry.number)  ").fontWeight(.semibold) + Text(clues[entry.id] ?? ""))
                                        .font(KelimeFont.ui(15, relativeTo: .body))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if game.isSolved(entry) {
                                        Text("✓").font(KelimeFont.ui(15, weight: .bold)).foregroundStyle(Palette.greenInk)
                                    }
                                }
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 50)
                                .background(Palette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(game.helped.contains(entry.id) ? Palette.amber : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.surface.ignoresSafeArea())
    }
}
