import KelimeCore
import KelimeUI
import SwiftUI

/// A 10-question Quick Review session, then its summary.
struct QuickReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var session: ReviewSession?
    @State private var picked: String?
    @State private var typed = ""
    @State private var lastCorrect: Bool?
    @State private var lastAnswer = ""
    @State private var isSaving = false

    var body: some View {
        Group {
            if let session {
                if session.isFinished {
                    ReviewSummaryView(session: session) { dismiss() } onMore: {
                        Task { await startAnotherRound() }
                    }
                } else if let question = session.current {
                    questionScreen(question, session: session)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screenBackground()
        .task { await load() }
    }

    // MARK: - Loading

    private func load() async {
        guard session == nil else { return }
        let deck = model.router.reviewDeck, today = model.clock.today
        let questions: [ReviewQuestion] = await model.read { db -> [ReviewQuestion] in
            var rng = SystemRandomNumberGenerator()
            return try QuickReview.makeQuestions(db: db, deck: deck, today: today, using: &rng)
        } ?? []
        if questions.isEmpty { dismiss(); return }
        session = ReviewSession(questions: questions)
    }

    private func startAnotherRound() async {
        session = nil
        picked = nil
        typed = ""
        lastCorrect = nil
        await load()
    }

    // MARK: - Question

    private func questionScreen(_ question: ReviewQuestion, session: ReviewSession) -> some View {
        VStack(spacing: 0) {
            topBar(session)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.kicker)
                        .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                        .tracking(1)
                        .foregroundStyle(Palette.ink2)
                    Text(question.card.meaning)
                        .font(KelimeFont.ui(30, weight: .semibold, relativeTo: .title))
                        .tracking(-0.4)
                    switch question.kind {
                    case .meaning(let options):
                        options_(options, question: question).padding(.top, 16)
                        if !session.awaitingContinue {
                            Button("Bilmiyorum") { Task { await submit("", question: question) } }
                                .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(Palette.ink2)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .disabled(isSaving)
                        }
                    case .write:
                        writeArea(question).padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if session.awaitingContinue, let correct = lastCorrect {
                feedback(question, correct: correct, answer: lastAnswer)
            } else if case .write = question.kind {
                // "Bilmiyorum" counts as a wrong answer and shows the word.
                HStack(spacing: 10) {
                    Button("Bilmiyorum") { Task { await submit("", question: question) } }
                        .buttonStyle(OutlineButtonStyle())
                        .frame(minHeight: 50)
                        .disabled(isSaving)
                    Button("Kontrol et") { Task { await submit(typedAnswer(question), question: question) } }
                        .buttonStyle(PrimaryButtonStyle())
                        .opacity(typed.count == question.card.word.count - 1 ? 1 : 0.5)
                        .disabled(typed.count != question.card.word.count - 1 || isSaving)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                LetterKeyboard { letter in
                    if typed.count < question.card.word.count - 1 { typed.append(letter) }
                } onDelete: {
                    if !typed.isEmpty { typed.removeLast() }
                }
            }
        }
    }

    private func topBar(_ session: ReviewSession) -> some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kapat")
            ThinProgressBar(fraction: session.progress, color: Palette.accent)
                .animation(.easeOut(duration: 0.3), value: session.progress)
            Text("\(min(session.index + 1, session.questions.count))/\(session.questions.count)")
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
    }

    private func options_(_ options: [String], question: ReviewQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                let answered = picked != nil
                let right = option == question.card.word
                let chosen = option == picked
                Button {
                    guard picked == nil, !isSaving else { return }
                    picked = option
                    Task { await submit(option, question: question) }
                } label: {
                    HStack {
                        Text(option).font(KelimeFont.english(24, relativeTo: .title2))
                        Spacer()
                        if answered && right {
                            Text("✓").font(KelimeFont.ui(16, weight: .bold)).foregroundStyle(Palette.greenInk)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 60)
                    .background(
                        answered && right ? Palette.greenBackground : answered && chosen ? Palette.amberBackground : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(answered && right ? Palette.green : answered && chosen ? Palette.amber : Palette.line, lineWidth: 1.5)
                    )
                    .opacity(answered && !right && !chosen ? 0.45 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.2), value: picked)
            }
        }
    }

    private func writeArea(_ question: ReviewQuestion) -> some View {
        let word = Array(question.card.word)
        let answered = lastCorrect != nil
        return VStack(alignment: .leading, spacing: 22) {
            Text(question.blankedSentence)
                .font(KelimeFont.english(22, relativeTo: .title2, italic: true))
                .foregroundStyle(Palette.ink2)
            HStack(spacing: 5) {
                ForEach(word.indices, id: \.self) { i in
                    let letter: String = {
                        if i == 0 { return String(word[0]).uppercased() }
                        if lastCorrect == false { return ReviewQuestion.asciiUpper(String(word[i])) }
                        let chars = Array(typed)
                        return i - 1 < chars.count ? String(chars[i - 1]) : ""
                    }()
                    let isCursor = !answered && i == typed.count + 1
                    Text(letter)
                        .font(KelimeFont.ui(22, weight: .semibold))
                        .foregroundStyle(i == 0 ? Palette.ink2 : Palette.ink)
                        .frame(width: 34, height: 46)
                        .background(boxColor(index: i), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isCursor ? Palette.accent : Palette.line, lineWidth: 1.5)
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(word.count) harf, ilk harf \(String(word[0]).uppercased()). Yazılan: \(typed)"))
        }
    }

    private func boxColor(index: Int) -> Color {
        if index == 0 { return Palette.surface2 }
        switch lastCorrect {
        case true?: return Palette.greenBackground
        case false?: return Palette.amberBackground
        case nil: return Palette.surface
        }
    }

    private func typedAnswer(_ question: ReviewQuestion) -> String {
        String(question.card.word.prefix(1)) + typed
    }

    private func feedback(_ question: ReviewQuestion, correct: Bool, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(correct ? "Doğru" : "Doğru cevap: \(question.card.word)")
                .font(KelimeFont.ui(20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(correct ? Palette.greenInk : Palette.amberInk)
            if !correct, let hint = question.mistakeHint(answer) {
                VStack(alignment: .leading, spacing: 4) {
                    typedWord(answer, word: question.card.word)
                    Text(hint)
                        .font(KelimeFont.ui(15, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(Palette.amberInk)
                }
            } else if !correct, !answer.isEmpty, case .meaning = question.kind {
                Text("Seçtiğin: \(answer)")
                    .font(KelimeFont.ui(15, relativeTo: .subheadline))
                    .foregroundStyle(Palette.amberInk)
                    .strikethrough()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(question.card.exampleEN)
                    .font(KelimeFont.english(23, relativeTo: .title3, italic: true))
                    .foregroundStyle(Palette.ink)
                Text(question.card.exampleTR)
                    .font(KelimeFont.ui(17, relativeTo: .body))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
            .fixedSize(horizontal: false, vertical: true)
            if !correct {
                Text("Bu kelimeyi widget'ında daha sık göreceksin")
                    .font(KelimeFont.ui(16, weight: .medium, relativeTo: .callout))
                    .foregroundStyle(Palette.amberInk)
            }
            Button("Devam") { next() }
                .buttonStyle(InkButtonStyle())
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(correct ? Palette.greenBackground : Palette.amberBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// The typed answer with its wrong letters marked: "wom[e]n → woman".
    private func typedWord(_ answer: String, word: String) -> some View {
        let wrong = Set(ReviewQuestion.wrongPositions(answer, word))
        let letters = Array(answer.lowercased())
        var text = Text("")
        for (index, letter) in letters.enumerated() {
            let piece = Text(String(letter))
            text = text + (wrong.contains(index)
                ? piece.foregroundColor(Palette.amberInk).underline()
                : piece.foregroundColor(Palette.ink))
        }
        return (text + Text("  →  ").foregroundColor(Palette.ink2) + Text(word).foregroundColor(Palette.greenInk))
            .font(KelimeFont.english(24, relativeTo: .title3))
            .accessibilityLabel("Yazdığın \(answer), doğrusu \(word)")
    }

    // MARK: - Actions

    private func submit(_ answer: String, question: ReviewQuestion) async {
        guard var current = session, !current.awaitingContinue else { return }
        isSaving = true
        let correct = question.isCorrect(answer)
        let states = await model.answerReview(cardID: question.id, correct: correct, sessionID: current.id)
        current.record(correct: correct, before: states?.before ?? .new, after: states?.after ?? (correct ? .learned : .struggling))
        withAnimation(.spring(duration: 0.3)) {
            session = current
            lastCorrect = correct
            lastAnswer = answer
        }
        isSaving = false
    }

    private func next() {
        guard var current = session else { return }
        current.advance()
        picked = nil
        typed = ""
        lastCorrect = nil
        withAnimation { session = current }
    }
}

/// Dark "Devam" button from the design (ink background, page-colored text).
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

struct ReviewSummaryView: View {
    let session: ReviewSession
    let onDone: () -> Void
    let onMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("TUR BİTTİ")
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .tracking(1)
                .foregroundStyle(Palette.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(session.score)").font(KelimeFont.english(96, relativeTo: .largeTitle)).tracking(-2.5)
                Text("/ \(session.questions.count)").font(KelimeFont.ui(20, relativeTo: .title3)).foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .combine)
            if !session.newlyLearned.isEmpty {
                chips("Öğrenildi", words: session.newlyLearned, ink: Palette.greenInk, background: Palette.greenBackground)
            }
            if !session.newlyStruggling.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    chips("Zorlanılan", words: session.newlyStruggling, ink: Palette.amberInk, background: Palette.amberBackground)
                    Text("Bunlar gün boyu kilit ekranında")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                }
            }
            Spacer()
            Button("Bitti", action: onDone).buttonStyle(PrimaryButtonStyle(height: 52))
            Button("Bir tur daha", action: onMore)
                .buttonStyle(OutlineButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    private func chips(_ title: String, words: [Card], ink: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(ink)
            FlowLayout(spacing: 6) {
                ForEach(words, id: \.id) { card in
                    Text(card.word)
                        .font(KelimeFont.english(18, relativeTo: .body))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(background, in: Capsule())
                }
            }
        }
    }
}

/// Wrapping row layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
