import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

@main
struct KelimeWatchWidgets: WidgetBundle {
    var body: some Widget {
        WordComplication()
        ReviewRingComplication()
    }
}

/// Reads the payload the watch app received from the iPhone.
struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshot {
        SampleContent.snapshot()
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshot) -> Void) {
        if context.isPreview { return completion(SampleContent.snapshot()) }
        completion(entries().first ?? SampleContent.snapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshot>) -> Void) {
        let entries = entries()
        if entries.isEmpty {
            // Nothing from the phone yet: ask again in an hour.
            completion(Timeline(entries: [.empty(at: .now)], policy: .after(.now.addingTimeInterval(3600))))
        } else {
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private func entries() -> [WidgetSnapshot] {
        WatchPayloadStore.load()?.snapshots(from: .now, calendar: .current) ?? []
    }
}

/// The word on the wrist: rectangular (also the Smart Stack), inline and corner.
struct WordComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchWord", provider: WatchProvider()) { entry in
            WatchWordView(entry: entry)
        }
        .configurationDisplayName("Kelime")
        .description("O saatin kelimesi ve anlamı.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

/// Today's reviews against the daily target, as a ring.
struct ReviewRingComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchReviewRing", provider: WatchProvider()) { entry in
            ReviewRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Günlük tekrar")
        .description("Bugünkü tekrarların ve hedefin.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct WatchWordView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        case .accessoryCorner:
            corner
        default:
            RectangularWidgetView(entry: entry)
        }
    }

    private var corner: some View {
        Text(entry.card?.word ?? "kelime")
            .font(KelimeFont.english(16))
            .widgetCurvesContent()
            .widgetLabel {
                Text(entry.card?.primaryMeaning ?? "")
            }
            .containerBackground(for: .widget) { Color.clear }
    }
}
