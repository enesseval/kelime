import KelimeCore
import KelimeUI
import SwiftUI

/// The optional placement test from onboarding's level step: about two minutes, two words per
/// level, and a suggested level at the end.
struct PlacementTestView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let available: [CEFRLevel]
    let onResult: (CEFRLevel) -> Void

    @State private var questions: [CEFRLevel: [PlacementQuestion]] = [:]
    @State private var level: CEFRLevel?
    @State private var index = 0
    @State private var correctInLevel = 0
    @State private var scores: [(CEFRLevel, Int)] = []
    @State private var picked: String?
    @State private var result: CEFRLevel?

    private var asked: Int { scores.count * PlacementTest.perLevel + index }

    var body: some View {
        ZStack {
            OnboardingSky(hour: 20.5)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Vazgeç") { dismiss() }
                        .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minHeight: 44)
                    Spacer()
                    if result == nil, level != nil {
                        Text("\(asked + 1). soru").font(KelimeFont.ui(13, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                if let result {
                    resultView(result)
                } else if let level, let question = questions[level]?[safe: index] {
                    questionView(question)
                } else {
                    Spacer()
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.dark)
        .task {
            questions = await app.read { db in
                var rng = SystemRandomNumberGenerator()
                return try PlacementTest.questions(db: db, using: &rng)
            } ?? [:]
            level = PlacementTest.nextLevel(after: [], available: available.filter { questions[$0] != nil })
        }
    }

    private func questionView(_ question: PlacementQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bu kelimenin anlamı ne?")
                .font(KelimeFont.ui(15, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.75))
            Text(question.card.word)
                .font(KelimeFont.english(52, relativeTo: .largeTitle))
                .tracking(-1)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 8)
            ForEach(question.options, id: \.self) { option in
                Button { answer(option, for: question) } label: {
                    Text(option)
                        .font(KelimeFont.ui(17, weight: .medium, relativeTo: .body))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .padding(.horizontal, 18)
                        .background(background(for: option, question: question), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
            }
            Button("Bilmiyorum") { answer("", for: question) }
                .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 48)
                .disabled(picked != nil)
        }
        .id(question.id)
        .transition(.opacity)
        .sensoryFeedback(.selection, trigger: picked)
    }

    private func background(for option: String, question: PlacementQuestion) -> AnyShapeStyle {
        guard let picked else { return AnyShapeStyle(.ultraThinMaterial) }
        if option == question.answer { return AnyShapeStyle(Palette.green.opacity(0.55)) }
        if option == picked { return AnyShapeStyle(Palette.amber.opacity(0.55)) }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func resultView(_ result: CEFRLevel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Önerilen seviyen")
                .font(KelimeFont.ui(15, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.75))
            Text(result.rawValue)
                .font(KelimeFont.english(96, relativeTo: .largeTitle))
                .foregroundStyle(.white)
            Text(LevelSamples.words(for: result).joined(separator: ", "))
                .font(KelimeFont.english(20, relativeTo: .body, italic: true))
                .foregroundStyle(.white.opacity(0.7))
            Text("Kolay ya da zor gelirse seviyeni istediğin zaman Ayarlar'dan değiştirebilirsin.")
                .font(KelimeFont.ui(15, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            HStack(spacing: 12) {
                Button("Kendim seçeyim") { dismiss() }.buttonStyle(GlassButtonStyle())
                Button("\(result.rawValue) ile başla") {
                    onResult(result)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(height: 54))
            }
        }
    }

    private func answer(_ option: String, for question: PlacementQuestion) {
        picked = option.isEmpty ? "—" : option
        let correct = option == question.answer
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            if correct { correctInLevel += 1 }
            picked = nil
            guard let current = level else { return }
            if index + 1 < PlacementTest.perLevel {
                withAnimation { index += 1 }
                return
            }
            scores.append((current, correctInLevel))
            correctInLevel = 0
            index = 0
            let levels = available.filter { questions[$0] != nil }
            if let next = PlacementTest.nextLevel(after: scores, available: levels) {
                withAnimation { level = next }
            } else {
                withAnimation { result = PlacementTest.result(scores, available: levels) }
                UsageCounter.count(.placementTest)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
