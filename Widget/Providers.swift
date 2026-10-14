import KelimeCore
import KelimeUI
import WidgetKit

/// Reads timelines from the shared database. Never touches the network.
enum WidgetData {
    static func snapshots(mode: WidgetMode?) -> [WidgetSnapshot] {
        do {
            let db = try AppDatabase.openShared()
            var rng = SystemRandomNumberGenerator()
            return try db.writer.write { db in
                try WidgetTimelineBuilder.build(db: db, clock: .system, mode: mode, using: &rng)
            }
        } catch {
            return [.empty(at: .now)]
        }
    }

    static func ring() -> [WidgetSnapshot] {
        do {
            let db = try AppDatabase.openShared()
            return try db.reader.read { db in try WidgetTimelineBuilder.ringSnapshots(db: db, clock: .system) }
        } catch {
            return [.empty(at: .now)]
        }
    }

    /// The entry on screen right now: the latest one that has started.
    static func current(_ snapshots: [WidgetSnapshot]) -> WidgetSnapshot {
        snapshots.last { $0.date <= .now } ?? snapshots.first ?? .empty(at: .now)
    }
}

struct WordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshot {
        SampleContent.snapshot()
    }

    func snapshot(for configuration: WordWidgetIntent, in context: Context) async -> WidgetSnapshot {
        if context.isPreview {
            return SampleContent.snapshot(mode: configuration.mode.mode ?? .card)
        }
        return WidgetData.current(WidgetData.snapshots(mode: configuration.mode.mode))
    }

    func timeline(for configuration: WordWidgetIntent, in context: Context) async -> Timeline<WidgetSnapshot> {
        Timeline(entries: WidgetData.snapshots(mode: configuration.mode.mode), policy: .atEnd)
    }
}

struct QuizProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshot {
        SampleContent.snapshot()
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshot) -> Void) {
        completion(context.isPreview ? SampleContent.snapshot() : WidgetData.current(WidgetData.snapshots(mode: .card)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshot>) -> Void) {
        completion(Timeline(entries: WidgetData.snapshots(mode: .card), policy: .atEnd))
    }
}

struct RingProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshot {
        SampleContent.snapshot()
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshot) -> Void) {
        completion(context.isPreview ? SampleContent.snapshot() : WidgetData.current(WidgetData.ring()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshot>) -> Void) {
        completion(Timeline(entries: WidgetData.ring(), policy: .atEnd))
    }
}
