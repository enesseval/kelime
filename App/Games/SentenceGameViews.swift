import KelimeCore
import KelimeUI
import SwiftUI

// MARK: - Cümle Kur

/// Cümle Kur: build the English sentence from shuffled word cards under the Turkish one.
/// Five sentences, two tries each; a wrong check shakes the misplaced cards.
struct SentenceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var game: SentenceGame?
    @State private var seconds = 0
    @State private var finished = false
    @State private var failed = false
    @State private var wrongPlaces: Set<Int> = []
    @State private var shakes = 0
    @State private var busy = false
    @State private var rights = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            if let game {
                if finished { result(game) } else { play(game) }
            } else if failed {
                ContentUnavailableView("Yeterli kelime yok", systemImage: "text.word.spacing", description: Text("Widget'ında açık bir liste ya da kurs olmalı."))
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
        .sensoryFeedback(.success, trigger: rights)
        .sensoryFeedback(.error, trigger: shakes)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink2).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kapat")
            Spacer()
            Text("Cümle Kur").font(KelimeFont.ui(15, weight: .semibold, relativeTo: .headline))
            Spacer()
            Text(game.map { "\(min($0.index + 1, $0.items.count))/\($0.items.count)" } ?? "")
                .font(KelimeFont.ui(14, weight: .bold, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
                .monospacedDigit()
                .frame(width: 44)
        }
        .padding(.horizontal, 8)
    }

    private func play(_ game: SentenceGame) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                if let item = game.current {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(item.card.exampleTR).font(KelimeFont.ui(20, weight: .medium, relativeTo: .title3))
                        rowBox(game, item)
                        FlowLayout(spacing: 8) {
                            ForEach(Array(item.tileOrder.indices), id: \.self) { tile in
                                if game.placed(tile) {
                                    // Same-size empty slot: the other cards never shift.
                                    tileView(item.tileText(tile), tint: .plain) {}
                                        .hidden()
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                                        .accessibilityHidden(true)
                                } else {
                                    tileView(item.tileText(tile), tint: .plain) { place(tile) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            if game.current != nil {
                Group {
                    if game.revealed {
                        Button(game.index + 1 >= game.items.count ? "Bitir" : "Sıradaki cümle") { advance() }
                            .buttonStyle(PrimaryButtonStyle(height: 52))
                    } else {
                        Button("Kontrol et") { check() }
                            .buttonStyle(PrimaryButtonStyle(height: 52))
                            .opacity(game.canCheck && !busy ? 1 : 0.45)
                            .disabled(!game.canCheck || busy)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
    }

    private func rowBox(_ game: SentenceGame, _ item: SentenceGame.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if game.revealed {
                Text("Doğrusu").font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption)).foregroundStyle(Palette.amberInk)
                Text(item.sentence).font(KelimeFont.english(22, relativeTo: .title3))
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(game.row.enumerated()), id: \.element) { place, tile in
                        let tint: TileTint = game.solved ? .right : wrongPlaces.contains(place) ? .wrong : .picked
                        tileView(SentenceTokens.shown(item.tileText(tile), position: place), tint: tint) { remove(place) }
                            .modifier(RowShake(amount: wrongPlaces.contains(place) ? 7 : 0, shakes: CGFloat(shakes)))
                    }
                }
                if game.row.isEmpty {
                    Text("Kartlara dokunarak cümleyi kur").font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(game.solved ? Palette.green : Palette.line, lineWidth: game.solved ? 2 : 1))
    }

    private func result(_ game: SentenceGame) -> some View {
        let score = game.firstTryCount, total = game.items.count
        return GameResultView(
            title: "Tur bitti",
            headline: "\(score) / \(total) doğru",
            stats: [("süre", Self.time(seconds)), ("zorlandığın", "\(game.failedCards.count)")],
            words: game.failedCards,
            wordsTitle: "Widget'ında daha sık görünecek",
            sentences: game.items.map { ($0.card.id, $0.sentence, $0.card.exampleTR) },
            onAgain: { Task { await restart() } },
            onClose: { dismiss() },
            share: { style in
                GameShareCard(title: "CÜMLE KUR", headline: "\(score) / \(total) doğru", detail: Self.time(seconds),
                              words: game.firstTryCards, style: style)
            }
        )
    }

    static func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    // MARK: Actions

    private func place(_ tile: Int) {
        guard !busy, var g = game, !g.solved, !g.revealed else { return }
        g.place(tile)
        game = g
    }

    private func remove(_ rowPlace: Int) {
        guard !busy, var g = game else { return }
        g.remove(rowPlace: rowPlace)
        wrongPlaces = []
        game = g
    }

    private func check() {
        guard !busy, var g = game, g.canCheck else { return }
        let outcome = g.check()
        withAnimation(.easeInOut(duration: 0.2)) { game = g }
        switch outcome {
        case .correct:
            rights += 1
            busy = true
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                advance()
            }
        case .wrong(let places):
            wrongPlaces = places
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                if wrongPlaces == places { withAnimation(.easeOut(duration: 0.2)) { wrongPlaces = [] } }
            }
        case .revealed:
            shakes += 1
        case nil:
            break
        }
    }

    private func advance() {
        guard var g = game else { return }
        g.next()
        wrongPlaces = []
        busy = false
        withAnimation(.easeInOut(duration: 0.2)) { game = g }
        guard g.isFinished, !finished else { return }
        withAnimation { finished = true }
        let clock = model.clock, secs = seconds, score = g.firstTryCount
        let done = g
        Task {
            await model.recordStudy(.sentence)
            await model.write(rebuildQueue: false) { db in try done.record(seconds: secs, clock: clock, db: db) }
            Analytics.signal("game.sentence.finished", ["score": "\(score)", "seconds": "\(secs)"])
        }
    }

    private func load() async {
        let clock = model.clock
        let loaded: SentenceGame? = await model.read { db in
            var rng = SystemRandomNumberGenerator()
            let cards = try GamePool.cards(count: SentenceGame.pool, singleWords: false, where: SentenceTokens.usable, db: db, today: clock.today, using: &rng)
            let g = SentenceGame(cards: cards, using: &rng)
            return g.items.count >= 3 ? g : nil
        } ?? nil
        game = loaded
        failed = loaded == nil
    }

    private func restart() async {
        game = nil
        seconds = 0
        finished = false
        busy = false
        wrongPlaces = []
        await load()
    }
}

// MARK: - Boşluğu Doldur

/// Boşluğu Doldur: the English sentence with the word blanked, four choices, sixty seconds.
/// Right goes green; wrong goes amber (never red) with the right word green, then the next one.
struct GapFillView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var game: GapFillGame?
    @State private var remaining = GapFillGame.seconds
    @State private var started = false
    @State private var finished = false
    /// The option tapped; set at once, it locks the options while the word types into the gap.
    @State private var chosen: Int?
    /// What the gap shows while typing and afterwards; nil before an answer.
    @State private var typed: String?
    /// The colour feedback shows once the typing is done.
    @State private var colored = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var best = 0
    @State private var failed = false
    @State private var misses = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            if let game {
                if finished {
                    result(game)
                } else if !started {
                    intro
                } else {
                    question(game)
                }
            } else if failed {
                ContentUnavailableView("Yeterli kelime yok", systemImage: "square.and.pencil", description: Text("Widget'ında açık bir liste ya da kurs olmalı."))
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
                if !finished && !Task.isCancelled { remaining -= 1 }
            }
            // Closing the page cancels this task; only a clock that really ran out ends the round.
            if !finished && !Task.isCancelled && remaining <= 0 { finish() }
        }
        .sensoryFeedback(.success, trigger: game?.score ?? 0) { old, new in new > old }
        .sensoryFeedback(.error, trigger: misses)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink2).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kapat")
            Spacer()
            Text("Boşluğu Doldur").font(KelimeFont.ui(15, weight: .semibold, relativeTo: .headline))
            Spacer()
            Text("\(remaining)")
                .font(KelimeFont.ui(15, weight: .bold, relativeTo: .headline))
                .foregroundStyle(remaining <= 10 && started && !finished ? Palette.amberInk : Palette.ink2)
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
            Text("Cümledeki boşluğa uyan kelimeyi seç. Ne kadar çok doğru, o kadar çok puan.")
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

    private func question(_ game: GapFillGame) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(game.score) doğru")
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity)
            if let q = game.current {
                VStack(alignment: .leading, spacing: 6) {
                    Text(gapSentence(q))
                        .font(KelimeFont.english(26, relativeTo: .title2))
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? .easeIn(duration: 0.25) : nil, value: typed)
                    Text(q.translation).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2.opacity(0.7))
                }
                .id(q.card.id)
                VStack(spacing: 10) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                        let shownPick = colored ? chosen : nil
                        let tint: TileTint = shownPick == nil ? .plain : i == q.answerIndex ? .right : i == shownPick ? .wrong : .plain
                        tileView((tint == .right ? "✓ " : tint == .wrong ? "✕ " : "") + option, tint: tint, fill: true) { choose(i) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    /// The sentence with the typed word in the gap: amber when wrong, green when right (after the typing).
    private func gapSentence(_ q: GapFill.Question) -> AttributedString {
        guard let typed else { return AttributedString(q.sentence) }
        var out = AttributedString()
        let parts = q.sentence.components(separatedBy: GapFill.blank)
        for (i, part) in parts.enumerated() {
            out += AttributedString(part)
            if i < parts.count - 1 {
                var word = AttributedString(typed)
                if colored {
                    word.foregroundColor = chosen == q.answerIndex ? Palette.greenInk : Palette.amberInk
                } else {
                    word.foregroundColor = Palette.accent
                }
                out += word
            }
        }
        return out
    }

    private func result(_ game: GapFillGame) -> some View {
        GameResultView(
            title: game.score > best ? "Yeni rekor!" : "Süre doldu",
            headline: "\(game.score) doğru",
            stats: [("en iyi", "\(max(best, game.score))"), ("zorlandığın", "\(game.missedCards.count)")],
            words: game.missedCards,
            wordsTitle: "Widget'ında daha sık görünecek",
            onAgain: { Task { await restart() } },
            onClose: { dismiss() },
            share: { style in
                GameShareCard(title: "BOŞLUĞU DOLDUR", headline: "\(game.score) doğru", detail: "60 saniyede · \(game.answered) soru",
                              words: game.rightCards, style: style)
            }
        )
    }

    // MARK: Actions

    private func choose(_ option: Int) {
        guard chosen == nil, var g = game, let q = g.current else { return }
        chosen = option
        // The answer is recorded now, not after the animation: leaving mid-typing loses nothing.
        let right = g.answer(option)
        game = g
        if !right { misses += 1 }
        let word = q.options[option]
        Task {
            if reduceMotion {
                typed = word
            } else {
                // Typewriter: at most 0.4 s in all, equal time per letter.
                let letters = Array(word)
                let step = 0.4 / Double(max(letters.count, 1))
                for n in 1...max(letters.count, 1) {
                    typed = String(letters.prefix(n))
                    try? await Task.sleep(for: .seconds(step))
                }
            }
            guard !finished, game?.current?.card.id == q.card.id else { return }
            colored = true
            // Right: a short green flash. Wrong: amber, the right word green, one second.
            try? await Task.sleep(for: .milliseconds(right ? 350 : 1000))
            guard !finished, game?.current?.card.id == q.card.id else { return }
            var next = g
            next.next()
            game = next
            chosen = nil
            typed = nil
            colored = false
            if next.isOutOfQuestions { finish() }
        }
    }

    private func finish() {
        guard let game, !finished else { return }
        withAnimation { finished = true }
        let clock = model.clock, secs = GapFillGame.seconds - remaining, score = game.score
        let done = game
        // Nothing answered: not a played round, so no study day and no result.
        guard done.answered > 0 else { return }
        Task {
            await model.recordStudy(.gapFill)
            await model.write(rebuildQueue: false) { db in try done.record(seconds: secs, clock: clock, db: db) }
            Analytics.signal("game.gapfill.finished", ["score": "\(score)", "seconds": "\(secs)"])
        }
    }

    private func load() async {
        let clock = model.clock
        let loaded: ([GapFill.Question], Int)? = await model.read { db in
            var rng = SystemRandomNumberGenerator()
            let cards = try GamePool.cards(count: GapFillGame.pool, singleWords: false, where: GapFill.usable, db: db, today: clock.today, using: &rng)
            let questions = try GapFill.questions(db: db, cards: cards, using: &rng)
            return (questions, try GamePool.best(.gapFill, db: db))
        }
        if let loaded, loaded.0.count >= 3 {
            game = GapFillGame(questions: loaded.0)
            best = loaded.1
        } else {
            failed = true
        }
    }

    private func restart() async {
        if let game { best = max(best, game.score) }
        game = nil
        remaining = GapFillGame.seconds
        finished = false
        started = false
        chosen = nil
        typed = nil
        colored = false
        await load()
        started = game != nil
    }
}

// MARK: - Shared tile

enum TileTint { case plain, picked, right, wrong }

/// A word card: plain, picked into the row, green for right, amber for wrong (never red).
private func tileView(_ text: String, tint: TileTint, fill: Bool = false, action: @escaping () -> Void) -> some View {
    let background: Color = switch tint {
    case .plain: Palette.surface
    case .picked: Palette.accentSoft
    case .right: Palette.greenBackground
    case .wrong: Palette.amberBackground
    }
    let border: Color = switch tint {
    case .plain: Palette.line
    case .picked: Palette.accent
    case .right: Palette.green
    case .wrong: Palette.amber
    }
    let ink: Color = switch tint {
    case .right: Palette.greenInk
    case .wrong: Palette.amberInk
    default: Palette.ink
    }
    return Button(action: action) {
        Text(text)
            .font(KelimeFont.english(fill ? 20 : 19, relativeTo: .body))
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: fill ? 56 : 44)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(border, lineWidth: tint == .plain ? 1 : 2))
    }
    .buttonStyle(.plain)
}

/// A side-to-side shake for the misplaced cards; `shakes` counts up once per wrong check.
private struct RowShake: GeometryEffect {
    var amount: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(shakes * .pi * 4), y: 0))
    }
}
