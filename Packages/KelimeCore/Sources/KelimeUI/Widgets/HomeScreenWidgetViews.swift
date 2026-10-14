import KelimeCore
import SwiftUI
import WidgetKit

// Home-screen widgets: paper surface in light/dark, accent parts marked `widgetAccentable()` for
// the iOS 18 tinted mode, where the system drops colors and the background.
//
// The views live here so the app (Bugün hero, theme picker) renders exactly what the widget
// shows. Interactive buttons need the extension's App Intents, so the widget passes a
// `WidgetButtonMaker`; elsewhere the labels render as plain, non-interactive views.

public enum WidgetLink {
    public static func word(_ card: Card) -> URL { URL(string: "kelime://word/\(card.id)")! }
    public static let puzzle = URL(string: "kelime://puzzle")!
}

/// A tap target inside a widget.
public enum WidgetButtonAction: Sendable, Equatable {
    case markKnown(cardID: String)
    case markStruggling(cardID: String)
    case answer(cardID: String, option: String)
    /// A deep link to part of the app (the large widget has several tap areas).
    case open(URL)
}

/// Wraps a label in a button for `action`. The widget extension supplies App Intent buttons.
public typealias WidgetButtonMaker = @MainActor (WidgetButtonAction, AnyView) -> AnyView

/// Non-interactive default, for previews and in-app renders.
@MainActor public let plainWidgetButton: WidgetButtonMaker = { _, label in label }

extension View {
    /// Paper background shared by every home-screen widget.
    public func paperBackground() -> some View {
        containerBackground(Palette.paper, for: .widget)
    }
}

/// First launch / no data, for every home family.
public struct WidgetEmptyStateView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Circle()
                .strokeBorder(Palette.ink2, lineWidth: 1.5)
                .frame(width: 12, height: 12)
            Text("Kelimelerini görmek için uygulamayı bir kez aç")
                .font(KelimeFont.ui(14))
                .foregroundStyle(Palette.ink)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .paperBackground()
    }
}

/// systemSmall: level chip, state dot, the word and its meaning. Tapping opens the word.
public struct SmallWidgetView: View {
    let entry: WidgetSnapshot

    /// 32 pt for most words; long words step down toward the design's 21 pt for 16 letters.
    static func wordSize(for word: String) -> CGFloat {
        switch word.count {
        case ...9: 32
        case 10...12: 26
        default: 21
        }
    }

    public init(entry: WidgetSnapshot) {
        self.entry = entry
    }

    public var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LevelChip(card.level)
                    Spacer()
                    StateDot(entry.state, size: 10).widgetAccentable()
                }
                Spacer(minLength: 4)
                Text(card.word)
                    .font(KelimeFont.english(Self.wordSize(for: card.word)))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .widgetAccentable()
                Text(card.meaning)
                    .font(KelimeFont.ui(14))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .paperBackground()
            .widgetURL(WidgetLink.word(card))
            .accessibilityElement(children: .combine)
        } else {
            WidgetEmptyStateView()
        }
    }
}

/// The word, part of speech and meaning, as on the medium and large cards.
public struct CardHeader: View {
    let card: Card
    let state: LearningState
    var wordSize: CGFloat
    var showLevel: Bool

    public init(card: Card, state: LearningState, wordSize: CGFloat = 34, showLevel: Bool = true) {
        self.card = card
        self.state = state
        self.wordSize = wordSize
        self.showLevel = showLevel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(KelimeFont.english(wordSize))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Spacer(minLength: 8)
                if showLevel {
                    Text(card.level.rawValue)
                        .font(KelimeFont.ui(11, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                } else {
                    StateDot(state, size: 10).widgetAccentable()
                }
            }
            (Text(card.pos.abbreviation).font(KelimeFont.english(14, italic: true)).foregroundStyle(Palette.ink2)
                + Text("  ") + Text(card.meaning).font(KelimeFont.ui(14)).foregroundStyle(Palette.ink))
                .lineLimit(1)
        }
    }
}

/// systemMedium card with "Biliyorum" / "Zorlanıyorum" buttons that work without opening the app.
public struct MediumCardWidgetView: View {
    let entry: WidgetSnapshot
    let makeButton: WidgetButtonMaker

    public init(entry: WidgetSnapshot, makeButton: @escaping WidgetButtonMaker = plainWidgetButton) {
        self.entry = entry
        self.makeButton = makeButton
    }

    public var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 4) {
                CardHeader(card: card, state: entry.state)
                (Text(card.exampleEN).font(KelimeFont.english(14, italic: true)).foregroundStyle(Palette.ink.opacity(0.85))
                    + Text("  ") + Text(card.exampleTR).font(KelimeFont.ui(12)).foregroundStyle(Palette.ink2))
                    .lineLimit(2)
                    .padding(.top, 2)
                Spacer(minLength: 6)
                HStack(spacing: 8) {
                    makeButton(.markKnown(cardID: card.id), AnyView(
                        ActionLabel(title: "Biliyorum", ink: Palette.greenInk, background: Palette.greenBackground)
                    ))
                    makeButton(.markStruggling(cardID: card.id), AnyView(
                        ActionLabel(title: "Zorlanıyorum", ink: Palette.amberInk, background: Palette.amberBackground)
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paperBackground()
            .widgetURL(WidgetLink.word(card))
        } else {
            WidgetEmptyStateView()
        }
    }
}

private struct ActionLabel: View {
    let title: String
    let ink: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(KelimeFont.ui(14, weight: .semibold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .widgetAccentable()
    }
}

/// systemMedium quiz: unanswered, correct and wrong states.
public struct MediumQuizWidgetView: View {
    let entry: WidgetSnapshot
    let makeButton: WidgetButtonMaker

    public init(entry: WidgetSnapshot, makeButton: @escaping WidgetButtonMaker = plainWidgetButton) {
        self.entry = entry
        self.makeButton = makeButton
    }

    public var body: some View {
        if let card = entry.card {
            Group {
                switch entry.quizCorrect {
                case nil: question(card)
                case true?: correct(card)
                case false?: wrong(card)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paperBackground()
        } else {
            WidgetEmptyStateView()
        }
    }

    private func question(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HANGİSİ?")
                .font(KelimeFont.ui(12, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Palette.ink2)
            Text(card.meaning)
                .font(KelimeFont.ui(24, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ForEach(entry.quizOptions, id: \.self) { option in
                    makeButton(.answer(cardID: card.id, option: option), AnyView(
                        Text(option)
                            .font(KelimeFont.english(20))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
                            .contentShape(Rectangle())
                    ))
                }
            }
        }
    }

    private func correct(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(KelimeFont.english(32))
                    .foregroundStyle(Palette.ink)
                    .widgetAccentable()
                Spacer()
                Text("✓ Doğru")
                    .font(KelimeFont.ui(13, weight: .bold))
                    .foregroundStyle(Palette.greenInk)
            }
            Text(card.meaning)
                .font(KelimeFont.ui(14))
                .foregroundStyle(Palette.ink2)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.exampleEN).font(KelimeFont.english(16, italic: true)).foregroundStyle(Palette.ink)
                Text(card.exampleTR).font(KelimeFont.ui(12)).foregroundStyle(Palette.ink2)
            }
            .lineLimit(1)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.greenBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .widgetURL(WidgetLink.word(card))
    }

    private func wrong(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Doğru cevap")
                .font(KelimeFont.ui(13, weight: .semibold))
                .foregroundStyle(Palette.amberInk)
            Text(card.word)
                .font(KelimeFont.english(32))
                .foregroundStyle(Palette.ink)
                .widgetAccentable()
            (Text(card.meaning + " · ") + Text(entry.quizAnswer ?? "").strikethrough())
                .font(KelimeFont.ui(14))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Bu kelime sık gelecek")
                .font(KelimeFont.ui(14, weight: .semibold))
                .foregroundStyle(Palette.amberInk)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.amberBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .widgetURL(WidgetLink.word(card))
    }
}

/// systemLarge: current card, today's struggling words, daily crossword teaser.
public struct LargeWidgetView: View {
    let entry: WidgetSnapshot
    let makeButton: WidgetButtonMaker

    public init(entry: WidgetSnapshot, makeButton: @escaping WidgetButtonMaker = plainWidgetButton) {
        self.entry = entry
        self.makeButton = makeButton
    }

    public var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 12) {
                makeButton(.open(WidgetLink.word(card)), AnyView(
                    CardHeader(card: card, state: entry.state, wordSize: 38, showLevel: false)
                ))
                Rectangle().fill(Palette.line).frame(height: 1)
                Text("BUGÜN ZORLANDIKLARIN")
                    .font(KelimeFont.ui(11, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(Palette.ink2)
                if entry.struggling.isEmpty {
                    Text("Zorlandığın kelime yok. Bir Hızlı Tekrar ile başla.")
                        .font(KelimeFont.ui(14))
                        .foregroundStyle(Palette.ink2)
                } else {
                    VStack(spacing: 7) {
                        ForEach(entry.struggling, id: \.id) { word in
                            makeButton(.open(WidgetLink.word(word)), AnyView(
                                HStack(alignment: .firstTextBaseline) {
                                    Text(word.word).font(KelimeFont.english(18)).foregroundStyle(Palette.ink)
                                    Spacer()
                                    Text(word.primaryMeaning).font(KelimeFont.ui(14)).foregroundStyle(Palette.ink2)
                                }
                                .lineLimit(1)
                            ))
                        }
                    }
                }
                Spacer(minLength: 0)
                makeButton(.open(WidgetLink.puzzle), AnyView(
                    HStack(spacing: 12) {
                        MiniGrid()
                        (Text("Günün Bulmacası").font(KelimeFont.ui(14, weight: .semibold)).foregroundStyle(Palette.ink)
                            + Text(" · yeni bulmaca").font(KelimeFont.ui(14, weight: .medium)).foregroundStyle(Palette.ink2))
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Palette.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paperBackground()
        } else {
            WidgetEmptyStateView()
        }
    }
}

/// Decorative crossword thumbnail from the design (8 × 10 cells of 5 pt).
public struct MiniGrid: View {
    private let cell: CGFloat = 5
    private let gap: CGFloat = 1

    public init() {}

    public var body: some View {
        Canvas { context, _ in
            func bar(col: Int, row: Int, width: Int, height: Int, color: Color) {
                let rect = CGRect(
                    x: CGFloat(col) * (cell + gap),
                    y: CGFloat(row) * (cell + gap),
                    width: CGFloat(width) * (cell + gap) - gap,
                    height: CGFloat(height) * (cell + gap) - gap
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
            bar(col: 2, row: 0, width: 6, height: 1, color: Palette.green)
            bar(col: 3, row: 1, width: 1, height: 6, color: Palette.green)
            bar(col: 0, row: 3, width: 8, height: 1, color: Palette.ink2.opacity(0.5))
            bar(col: 5, row: 4, width: 1, height: 6, color: Palette.ink2.opacity(0.3))
            bar(col: 1, row: 9, width: 7, height: 1, color: Palette.ink2.opacity(0.3))
        }
        .frame(width: 8 * (cell + gap) - gap, height: 10 * (cell + gap) - gap)
        .accessibilityHidden(true)
    }
}
