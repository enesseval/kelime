import KelimeCore
import SwiftUI
import WidgetKit

// Lock-screen widgets render vibrant (monochrome): white at opacity steps only, and the word's
// state is shown by dot shape (○ yeni · ◐ zorlanılan · ● öğrenildi), never by color.

/// accessoryInline: "reluctant · isteksiz".
public struct InlineWidgetView: View {
    let entry: WidgetSnapshot

    public init(entry: WidgetSnapshot) {
        self.entry = entry
    }

    public var body: some View {
        if let card = entry.card {
            Text("\(card.word) · \(card.primaryMeaning)")
                .widgetURL(WidgetLink.shown(entry, card: card, source: "lock"))
        } else {
            Text("Kilit Kelime'yi aç")
        }
    }
}

/// accessoryRectangular in Kart, Cümle and Kendini sına modes.
public struct RectangularWidgetView: View {
    let entry: WidgetSnapshot

    public init(entry: WidgetSnapshot) {
        self.entry = entry
    }

    public var body: some View {
        Group {
            if let card = entry.card {
                switch entry.mode {
                case .card:
                    cardMode(card)
                case .dictionary:
                    dictionaryMode(card)
                case .wordAndSentence:
                    wordAndSentenceMode(card)
                case .sentence:
                    sentenceMode(card)
                case .selfTest:
                    if entry.phase == .question { questionMode(card) } else { answerMode(card) }
                }
            } else {
                Text("Kelimelerini görmek için uygulamayı bir kez aç")
                    .font(KelimeFont.ui(12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetURL(entry.card.map { WidgetLink.shown(entry, card: $0, source: "lock") })
        .containerBackground(for: .widget) {
            // Sözlük sits straight on the wallpaper, like a line of text under the clock.
            if entry.mode == .dictionary { Color.clear } else { AccessoryWidgetBackground() }
        }
        .accessibilityElement(children: .combine)
    }

    /// "INEFFABLE (adj)" over the meaning, no plate behind it.
    private func dictionaryMode(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            (Text(ReviewQuestion.asciiUpper(card.word)).font(KelimeFont.ui(17, weight: .bold))
                + Text(card.isPhrase ? "" : " (\(card.pos.rawValue))").font(KelimeFont.ui(15, weight: .semibold)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(card.meaning)
                .font(KelimeFont.ui(14, weight: .medium))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .opacity(0.92)
        }
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func wordAndSentenceMode(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.word)
                .font(KelimeFont.english(22))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(card.exampleEN)
                .font(KelimeFont.english(13, italic: true))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func cardMode(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(card.word)
                .font(KelimeFont.english(26))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text("\(card.pos.abbreviation) · \(card.meaning)")
                .font(KelimeFont.ui(11.5))
                .opacity(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            StateDot(entry.state, size: 7, color: .white).widgetAccentable()
        }
    }

    private func sentenceMode(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(card.exampleEN)
                .font(KelimeFont.english(15, italic: true))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
            Text(card.exampleTR)
                .font(KelimeFont.ui(11))
                .opacity(0.65)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func questionMode(_ card: Card) -> some View {
        let pattern = card.selfTestPattern
        return VStack(alignment: .leading, spacing: 5) {
            Text("\(card.primaryMeaning) →")
                .font(KelimeFont.ui(12))
                .opacity(0.7)
                .lineLimit(1)
            (Text(pattern.first) + Text(pattern.blanks).foregroundStyle(.white.opacity(0.4)))
                .font(KelimeFont.mono(17))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
                .accessibilityLabel(Text("\(pattern.first) ile başlayan \(card.word.count) harfli kelime"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func answerMode(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(card.word)
                .font(KelimeFont.english(26))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(card.meaning)
                .font(KelimeFont.ui(11))
                .opacity(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// accessoryCircular: today's reviews against the daily target.
public struct ReviewRingWidgetView: View {
    let entry: WidgetSnapshot

    public init(entry: WidgetSnapshot) {
        self.entry = entry
    }

    public var body: some View {
        let progress = min(Double(entry.reviewedToday) / Double(max(entry.dailyTarget, 1)), 1)
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            VStack(spacing: 0) {
                Text("\(entry.reviewedToday)")
                    .font(KelimeFont.ui(18, weight: .bold))
                Text("/\(entry.dailyTarget)")
                    .font(KelimeFont.ui(9))
                    .opacity(0.6)
            }
        }
        .padding(4)
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Bugün \(entry.reviewedToday) / \(entry.dailyTarget) tekrar"))
    }
}
