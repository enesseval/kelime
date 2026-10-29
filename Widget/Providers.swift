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

    /// The timeline handed to iOS: 24 hours of entries, or in measurement mode only the
    /// current slot with a reload request for the next one. Every request is logged.
    static func timeline(mode: WidgetMode?, source: String) -> Timeline<WidgetSnapshot> {
        do {
            let db = try AppDatabase.openShared()
            var rng = SystemRandomNumberGenerator()
            return try db.writer.write { db in
                let all = try WidgetTimelineBuilder.build(db: db, clock: .system, mode: mode, using: &rng)
                let probe = try Settings.bool(.widgetProbe, in: db)
                var entries = all
                var reloadAt: Date?
                if probe {
                    (entries, reloadAt) = WidgetLog.probeTimeline(all, now: .now)
                }
                try WidgetLog.recordTimeline(source: source, entries: entries.count, probe: probe, reloadAt: reloadAt, db: db, clock: .system)
                return Timeline(entries: entries, policy: reloadAt.map { TimelineReloadPolicy.after($0) } ?? .atEnd)
            }
        } catch {
            return Timeline(entries: [.empty(at: .now)], policy: .after(.now.addingTimeInterval(15 * 60)))
        }
    }

    /// The quiz widget's entries: a fresh answer for a minute, then the next question.
    static func quiz() -> [WidgetSnapshot] {
        do {
            let db = try AppDatabase.openShared()
            var rng = SystemRandomNumberGenerator()
            return try db.writer.write { db in
                let entries = try WidgetTimelineBuilder.quiz(db: db, clock: .system, using: &rng)
                try WidgetLog.recordTimeline(source: "quiz", entries: entries.count, probe: false, reloadAt: nil, db: db, clock: .system)
                return entries
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
        WidgetData.timeline(mode: configuration.mode.mode, source: context.family.logName)
    }
}

struct QuizProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshot {
        SampleContent.snapshot()
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshot) -> Void) {
        completion(context.isPreview ? SampleContent.snapshot() : WidgetData.quiz().first ?? .empty(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshot>) -> Void) {
        completion(Timeline(entries: WidgetData.quiz(), policy: .atEnd))
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

extension WidgetFamily {
    /// Short name for the widget log.
    var logName: String {
        switch self {
        case .accessoryInline: "lock-inline"
        case .accessoryRectangular: "lock"
        case .accessoryCircular: "lock-circle"
        case .systemSmall: "home-small"
        case .systemMedium: "home-medium"
        case .systemLarge: "home-large"
        default: "other"
        }
    }
}
