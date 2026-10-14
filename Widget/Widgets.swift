import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

/// Wraps shared widget labels in App Intent buttons, so taps work without opening the app.
@MainActor let intentButton: WidgetButtonMaker = { action, label in
    switch action {
    case .markKnown(let cardID):
        AnyView(Button(intent: MarkKnownIntent(cardID: cardID)) { label }.buttonStyle(.plain))
    case .markStruggling(let cardID):
        AnyView(Button(intent: MarkStrugglingIntent(cardID: cardID)) { label }.buttonStyle(.plain))
    case .answer(let cardID, let option):
        AnyView(Button(intent: AnswerQuizIntent(cardID: cardID, option: option)) { label }.buttonStyle(.plain))
    case .open(let url):
        AnyView(Link(destination: url) { label })
    }
}

/// The main widget: lock screen inline/rectangular and home small/medium/large.
/// Each instance can pick its display mode; the default follows the app's setting.
struct WordWidget: Widget {
    static let kind = "WordWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: WordWidgetIntent.self, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Kelime")
        .description("Gün boyu bir kelime, anlamı ve örnek cümlesi.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .systemSmall, .systemMedium, .systemLarge])
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryInline: InlineWidgetView(entry: entry)
        case .accessoryRectangular: RectangularWidgetView(entry: entry)
        case .systemMedium: MediumCardWidgetView(entry: entry, makeButton: intentButton)
        case .systemLarge: LargeWidgetView(entry: entry, makeButton: intentButton)
        default: SmallWidgetView(entry: entry)
        }
    }
}

/// Medium quiz: the Turkish meaning with two English options.
struct QuizWidget: Widget {
    static let kind = "QuizWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuizProvider()) { entry in
            MediumQuizWidgetView(entry: entry, makeButton: intentButton)
        }
        .configurationDisplayName("Hangisi?")
        .description("Anlama bakıp doğru kelimeyi seç.")
        .supportedFamilies([.systemMedium])
    }
}

/// Lock-screen ring: today's reviews against the daily target.
struct ReviewRingWidget: Widget {
    static let kind = "ReviewRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RingProvider()) { entry in
            ReviewRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Bugünkü tekrar")
        .description("Bugün kaç kelime tekrar ettiğini gösterir.")
        .supportedFamilies([.accessoryCircular])
    }
}
