import KelimeCore
import KelimeUI
import SwiftUI

// MARK: - Kelime Avı

/// Kelime Avı: find the English words in the grid from their Turkish meanings. Drag across the
/// letters; a right line turns green and the meaning shows its word.
struct WordSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var game: WordSearch?
    @State private var found: Set<String> = []
    @State private var hinted: Set<String> = []
    @State private var selection: [WordSearch.Point] = []
    @State private var dragStart: WordSearch.Point?
    @State private var seconds = 0
    @State private var finished = false
    @State private var failed = false
    @State private var wrongFlash = false
    @State private var sharing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if let game {
                if finished {
                    result(game)
                } else {
                    play(game)
                }
            } else if failed {
                ContentUnavailableView("Yeterli kelime yok", systemImage: "square.grid.3x3", description: Text("Widget'ında açık bir liste ya da kurs olmalı."))
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screenBackground()
        .task { await load() }
        .task(id: finished) {
            while !finished && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if game != nil && !finished { seconds += 1 }
            }
        }
        .sensoryFeedback(.success, trigger: found.count)
        .sensoryFeedback(.error, trigger: wrongFlash)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink2).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kapat")
            Spacer()
            Text("Kelime Avı").font(KelimeFont.ui(15, weight: .semibold, relativeTo: .headline))
            Spacer()
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .monospacedDigit()
                .frame(width: 44)
        }
        .padding(.horizontal, 8)
    }

    private func play(_ game: WordSearch) -> some View {
        VStack(spacing: 18) {
            Text("\(found.count) / \(game.placements.count) kelime")
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
            grid(game)
                .padding(.horizontal, 16)
            clues(game)
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
            Button {
                hint(game)
            } label: {
                Label("İlk harfi göster", systemImage: "lightbulb")
            }
            .buttonStyle(TintedButtonStyle(height: 46))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
    }

    private func grid(_ game: WordSearch) -> some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(game.size)
            let foundCells = Set(game.placements.filter { found.contains($0.id) }.flatMap(\.cells))
            let hintCells = Set(game.placements.filter { hinted.contains($0.id) && !found.contains($0.id) }.map(\.start))
            let selected = Set(selection)
            ZStack(alignment: .topLeading) {
                ForEach(0..<game.size, id: \.self) { row in
                    ForEach(0..<game.size, id: \.self) { col in
                        let p = WordSearch.Point(row: row, col: col)
                        Text(String(game.letter(at: p)))
                            .font(KelimeFont.ui(cell * 0.46, weight: .semibold))
                            .foregroundStyle(foundCells.contains(p) ? Palette.greenInk : Palette.ink)
                            .frame(width: cell - 4, height: cell - 4)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected.contains(p) ? (wrongFlash ? Palette.amberBackground : Palette.accentSoft)
                                          : foundCells.contains(p) ? Palette.greenBackground
                                          : hintCells.contains(p) ? Palette.amberBackground : Palette.surface)
                            }
                            .position(x: CGFloat(col) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
                    }
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let start = point(value.startLocation, cell: cell, size: game.size),
                              let end = point(value.location, cell: cell, size: game.size) else { return }
                        dragStart = start
                        selection = WordSearch.line(from: start, to: end) ?? [start]
                    }
                    .onEnded { _ in check(game) }
            )
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Harf ızgarası")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func clues(_ game: WordSearch) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 8) {
            ForEach(game.placements) { p in
                let done = found.contains(p.id)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.card.primaryMeaning)
                        .font(KelimeFont.ui(14, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(done ? Palette.ink2 : Palette.ink)
                        .strikethrough(done)
                        .lineLimit(1)
                    Text(done ? p.card.word : "\(p.letters.count) harf")
                        .font(done ? KelimeFont.english(15, relativeTo: .subheadline) : KelimeFont.ui(12, relativeTo: .caption))
                        .foregroundStyle(done ? Palette.greenInk : Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func result(_ game: WordSearch) -> some View {
        GameResultView(
            title: "Kelime Avı tamam",
            headline: "\(game.placements.count) kelime",
            stats: [("süre", String(format: "%d:%02d", seconds / 60, seconds % 60)), ("ipucu", "\(hinted.count)")],
            words: game.placements.map(\.card),
            onAgain: { Task { await restart() } },
            onClose: { dismiss() },
            share: { style in
                GameShareCard(title: "KELİME AVI", headline: "\(game.placements.count) kelime",
                              detail: String(format: "%d:%02d", seconds / 60, seconds % 60) + " · \(hinted.count) ipucu",
                              words: game.placements.map(\.card), style: style)
            }
        )
    }

    // MARK: Actions

    private func point(_ location: CGPoint, cell: CGFloat, size: Int) -> WordSearch.Point? {
        let col = Int(location.x / cell), row = Int(location.y / cell)
        guard (0..<size).contains(row), (0..<size).contains(col) else { return nil }
        return WordSearch.Point(row: row, col: col)
    }

    private func check(_ game: WordSearch) {
        defer { if !wrongFlash { selection = [] } }
        guard selection.count >= 3 else { return }
        if let placement = game.placement(spelledBy: selection, skip: found) {
            found.insert(placement.id)
            let event: LearningEvent = hinted.contains(placement.id) ? .hintUsed : .answered(correct: true)
            Task { await model.record(event, cardID: placement.card.id, source: .game) }
            if found.count == game.placements.count { finish(game) }
        } else {
            wrongFlash.toggle()
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                selection = []
            }
        }
    }

    private func hint(_ game: WordSearch) {
        guard let next = game.placements.first(where: { !found.contains($0.id) && !hinted.contains($0.id) }) else { return }
        hinted.insert(next.id)
    }

    private func finish(_ game: WordSearch) {
        withAnimation { finished = true }
        let clock = model.clock, seconds = seconds, total = game.placements.count, score = total - hinted.count
        Task {
            await model.write(rebuildQueue: false) { db in
                try GamePool.recordResult(game: .wordSearch, score: score, total: total, seconds: seconds, clock: clock, db: db)
            }
            Analytics.signal("game.wordsearch.finished", ["seconds": "\(seconds)", "hints": "\(total - score)"])
        }
    }

    private func load() async {
        let clock = model.clock
        let size = UIScreen.main.bounds.width < 380 ? 7 : 8
        let made: WordSearch? = await model.read { db in
            var rng = SystemRandomNumberGenerator()
            let cards = try GamePool.cards(count: 24, singleWords: true, lengths: 3...size, db: db, today: clock.today, using: &rng)
            return WordSearch.make(cards: cards, size: size, wordCount: 6, using: &rng)
        } ?? nil
        game = made
        failed = made == nil
    }

    private func restart() async {
        game = nil
        found = []
        hinted = []
        seconds = 0
        finished = false
        await load()
    }
}

// MARK: - Eşleştir

/// Eşleştir: match English words to their Turkish meanings for a minute.
struct MatchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var game: MatchGame?
    @State private var remaining = Int(MatchGame.duration)
    @State private var started = false
    @State private var finished = false
    @State private var shake: String?
    @State private var best = 0
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if let game {
                if finished {
                    result(game)
                } else if !started {
                    intro
                } else {
                    board(game)
                }
            } else if failed {
                ContentUnavailableView("Yeterli kelime yok", systemImage: "rectangle.grid.2x2", description: Text("Widget'ında açık bir liste ya da kurs olmalı."))
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screenBackground()
        .task { await load() }
        .task(id: started) {
            guard started else { return }
            while remaining > 0 && !finished && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            if !finished { finish() }
        }
        .sensoryFeedback(.success, trigger: game?.score ?? 0)
        .sensoryFeedback(.error, trigger: shake)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink2).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kapat")
            Spacer()
            Text("Eşleştir").font(KelimeFont.ui(15, weight: .semibold, relativeTo: .headline))
            Spacer()
            Text("\(remaining)")
                .font(KelimeFont.ui(15, weight: .bold, relativeTo: .headline))
                .foregroundStyle(remaining <= 10 && started ? Palette.amberInk : Palette.ink2)
                .monospacedDigit()
                .frame(width: 44)
                .accessibilityLabel("\(remaining) saniye")
        }
        .padding(.horizontal, 8)
    }

    private var intro: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("60 saniye").font(KelimeFont.english(48, relativeTo: .largeTitle))
            Text("İngilizce kelimeyi Türkçe anlamıyla eşleştir. Doğru çift gider; üç çift gidince yenileri gelir.")
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if best > 0 {
                Text("En iyi skorun: \(best)").font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(Palette.greenInk)
            }
            Spacer()
            Button("Başla") { started = true }
                .buttonStyle(PrimaryButtonStyle(height: 52))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private func board(_ game: MatchGame) -> some View {
        VStack(spacing: 14) {
            Text("\(game.score) eşleşme")
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
            HStack(alignment: .top, spacing: 12) {
                column(game.english, game: game)
                column(game.turkish, game: game)
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private func column(_ tiles: [MatchGame.Tile?], game: MatchGame) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                ZStack {
                    // The slot keeps its height while a matched card fades out and the next fades in.
                    Color.clear
                    if let tile {
                        tileButton(tile, selected: game.selected?.id == tile.id)
                            .id(tile.id)
                            .transition(.asymmetric(
                                insertion: .opacity.animation(.easeIn(duration: 0.45).delay(0.25)),
                                removal: .opacity.animation(.easeOut(duration: 0.3))
                            ))
                    }
                }
                .frame(height: 68)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tileButton(_ tile: MatchGame.Tile, selected: Bool) -> some View {
        Button { tap(tile) } label: {
            Text(tile.text)
                .font(tile.side == .english ? KelimeFont.english(19, relativeTo: .body) : KelimeFont.ui(15, relativeTo: .subheadline))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selected ? Palette.accentSoft : shake == tile.id ? Palette.amberBackground : Palette.surface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : Palette.line, lineWidth: selected ? 2 : 1))
                .offset(x: shake == tile.id ? 6 : 0)
        }
        .buttonStyle(.plain)
    }

    private func result(_ game: MatchGame) -> some View {
        GameResultView(
            title: game.score >= best && game.score > 0 ? "Yeni rekor!" : "Süre doldu",
            headline: "\(game.score) eşleşme",
            stats: [("en iyi", "\(max(best, game.score))"), ("zorlandığın", "\(game.missed.count)")],
            words: game.missed,
            wordsTitle: "Widget'ında daha sık görünecek",
            onAgain: { Task { await restart() } },
            onClose: { dismiss() },
            share: { style in
                GameShareCard(title: "EŞLEŞTİR", headline: "\(game.score) eşleşme", detail: "60 saniyede",
                              words: game.firstTry, style: style)
            }
        )
    }

    // MARK: Actions

    private func tap(_ tile: MatchGame.Tile) {
        guard var current = game else { return }
        let missedBefore = current.missed.count
        let outcome = current.tap(tile)
        withAnimation(.easeInOut(duration: 0.3)) { game = current }
        switch outcome {
        case .match(let card):
            if !current.missed.contains(where: { $0.id == card.id }) {
                Task { await model.record(.answered(correct: true), cardID: card.id, source: .game) }
            }
            if current.isOutOfCards { finish() }
        case .miss(let english, _):
            // A word counts as missed once per round.
            if current.missed.count > missedBefore {
                Task { await model.record(.answered(correct: false), cardID: english.id, source: .game) }
            }
            withAnimation(.default.repeatCount(2, autoreverses: true)) { shake = english.id + "-en" }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                shake = nil
            }
        case nil:
            break
        }
    }

    private func finish() {
        guard let game, !finished else { return }
        withAnimation { finished = true }
        let clock = model.clock, score = game.score
        Task {
            await model.write(rebuildQueue: false) { db in
                try GamePool.recordResult(game: .match, score: score, total: score + game.missed.count, seconds: Int(MatchGame.duration), clock: clock, db: db)
            }
            Analytics.signal("game.match.finished", ["score": "\(score)"])
        }
    }

    private func load() async {
        let clock = model.clock
        let loaded: (MatchGame, Int)? = await model.read { db in
            var rng = SystemRandomNumberGenerator()
            let cards = try GamePool.cards(count: 40, singleWords: false, db: db, today: clock.today, using: &rng)
            guard cards.count >= MatchGame.boardSize else { return nil }
            return (MatchGame(cards: cards), try Settings.int(.matchBest, in: db) ?? 0)
        } ?? nil
        game = loaded?.0
        best = loaded?.1 ?? 0
        failed = loaded == nil
    }

    private func restart() async {
        if let game { best = max(best, game.score) }
        game = nil
        remaining = Int(MatchGame.duration)
        finished = false
        started = false
        await load()
        started = true
    }
}

// MARK: - Shared result screen and share card

struct GameResultView<ShareCard: View>: View {
    let title: String
    let headline: String
    let stats: [(String, String)]
    let words: [Card]
    var wordsTitle = "Bu turun kelimeleri"
    let onAgain: () -> Void
    let onClose: () -> Void
    @ViewBuilder let share: (ShareCardStyle) -> ShareCard
    @State private var sharing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title.uppercased(with: Locale(identifier: "tr_TR")))
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .tracking(1)
                .foregroundStyle(Palette.ink2)
            Text(headline).font(KelimeFont.english(52, relativeTo: .largeTitle)).tracking(-1)
            HStack(spacing: 24) {
                ForEach(stats, id: \.0) { stat in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(stat.1).font(KelimeFont.ui(20, weight: .bold, relativeTo: .title3))
                        Text(stat.0).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !words.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(wordsTitle).font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                    FlowLayout(spacing: 6) {
                        ForEach(words, id: \.id) { card in
                            Text(card.word)
                                .font(KelimeFont.english(18, relativeTo: .body))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Palette.surface2, in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Button("Sonucu paylaş") { sharing = true }
                .buttonStyle(PrimaryButtonStyle(height: 52))
            HStack {
                Button("Bir tur daha", action: onAgain)
                Spacer()
                Button("Kapat", action: onClose).fontWeight(.semibold)
            }
            .font(KelimeFont.ui(15, relativeTo: .subheadline))
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .askForReview(when: true)
        .sheet(isPresented: $sharing) {
            ShareImageSheet(title: "Sonuç", name: headline, card: share)
        }
    }
}

/// A game result as a 9:16 share image.
struct GameShareCard: View {
    let title: String
    let headline: String
    let detail: String
    let words: [Card]
    let style: ShareCardStyle

    var body: some View {
        ShareFrame(style: style) {
            Spacer().frame(height: 30)
            Text(title).font(KelimeFont.ui(14, weight: .bold)).tracking(1.4).foregroundStyle(Palette.ink2)
            Text(TurkishDate.header(.now)).font(KelimeFont.ui(15)).foregroundStyle(Palette.ink2).padding(.top, 2)
            Text(headline).font(KelimeFont.english(68)).tracking(-1.5).padding(.top, 20)
            Text(detail).font(KelimeFont.ui(20, weight: .semibold))
            if !words.isEmpty {
                Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 26)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(words.prefix(6), id: \.id) { card in
                        HStack(alignment: .firstTextBaseline) {
                            Text(card.word).font(KelimeFont.english(24))
                            Spacer()
                            Text(card.primaryMeaning).font(KelimeFont.ui(16)).foregroundStyle(Palette.ink2)
                        }
                        .lineLimit(1)
                    }
                }
            }
        }
    }
}
