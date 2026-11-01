import AppIntents
import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

/// Opens the app on a `kelime://` link from a Control Center button.
@available(iOS 18.0, *)
struct OpenKelimeLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Kilit Kelime'yi aç"
    static let isDiscoverable = false

    @Parameter(title: "Bağlantı")
    var link: String

    init() {}

    init(link: String) {
        self.link = link
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: link) ?? URL(string: "kelime://")!))
    }
}

/// Control Center: start a Quick Review round in one tap.
@available(iOS 18.0, *)
struct QuickReviewControl: ControlWidget {
    static let kind = "QuickReviewControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenKelimeLinkIntent(link: "kelime://review")) {
                Label("Hızlı Tekrar", systemImage: "bolt.circle")
            }
        }
        .displayName("Hızlı Tekrar")
        .description("Kilit Kelime'de 2 dakikalık bir tur başlatır.")
    }
}

/// Control Center: the word on the widget now; a tap opens it.
@available(iOS 18.0, *)
struct CurrentWordControl: ControlWidget {
    static let kind = "CurrentWordControl"

    struct Value: Sendable {
        var word: String
        var cardID: String?
    }

    struct Provider: ControlValueProvider {
        var previewValue: Value { Value(word: "reluctant", cardID: nil) }

        func currentValue() async throws -> Value {
            guard let db = try? AppDatabase.openShared() else { return previewValue }
            let card = try? await db.reader.read { db -> Card? in
                guard let entry = try WidgetQueue.current(db: db, clock: .system) else { return nil }
                return try Card.fetchOne(db, key: entry.cardID)
            }
            guard let card = card ?? nil else { return Value(word: "Kilit Kelime", cardID: nil) }
            return Value(word: card.word, cardID: card.id)
        }
    }

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { value in
            ControlWidgetButton(action: OpenKelimeLinkIntent(link: value.cardID.map { "kelime://word/\($0)" } ?? "kelime://")) {
                Label(value.word, systemImage: "text.book.closed")
            }
        }
        .displayName("Şu anki kelime")
        .description("Widget'ındaki kelimeyi gösterir; dokununca açar.")
    }
}

/// StandBy (a charging iPhone on its side): the word large and calm, no card behind it, so it
/// reads across the room and stays legible in the red night mode.
struct StandByWordView: View {
    let entry: WidgetSnapshot

    var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.word)
                    .font(KelimeFont.english(card.word.count > 10 ? 30 : 38))
                    .lineLimit(card.isPhrase ? 2 : 1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(card.meaning)
                    .font(KelimeFont.ui(16, weight: .medium))
                    .lineLimit(2)
                    .opacity(0.75)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(WidgetLink.word(card))
            .accessibilityElement(children: .combine)
        } else {
            WidgetEmptyStateView()
        }
    }
}
