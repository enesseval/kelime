import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

// Milestone 1 placeholder: proves the widget reads the shared App Group database.
// The real families, modes and timeline arrive in milestone 3.

struct WordEntry: TimelineEntry {
    let date: Date
    let card: Card?
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, card: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(WordEntry(date: .now, card: Self.loadCard()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let entry = WordEntry(date: .now, card: Self.loadCard())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3 * 3600))))
    }

    private static func loadCard() -> Card? {
        guard let db = try? AppDatabase.openShared() else { return nil }
        return try? db.reader.read { db in
            try Card.order(sql: "RANDOM()").fetchOne(db)
        }
    }
}

struct WordWidgetView: View {
    let entry: WordEntry

    var body: some View {
        Group {
            if let card = entry.card {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.level.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.ink2)
                    Spacer(minLength: 0)
                    Text(card.word)
                        .font(.system(size: 28, design: .serif))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(card.meaning)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 0)
                    StateDot(.new, size: 12, color: Palette.ink2)
                    Text("Kelimelerini görmek için uygulamayı bir kez aç")
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Palette.ink)
        .containerBackground(Palette.paper, for: .widget)
    }
}

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordWidget", provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Kelime")
        .description("Günün kelimesi ve anlamı.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    WordWidget()
} timeline: {
    WordEntry(date: .now, card: Card(id: "b1-reliable", word: "reliable", pos: .adjective, level: .b1, tr: ["güvenilir"], exampleEN: "He is a reliable friend.", exampleTR: "O, güvenilir bir arkadaş."))
    WordEntry(date: .now, card: nil)
}
