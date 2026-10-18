import KelimeCore
import WidgetKit

/// Keeps widgets in step with the app. Call after every state, settings, purchase or content change.
enum WidgetRefresher {
    /// Tops up the 24-hour queue and asks WidgetKit to rebuild every timeline.
    static func refresh(_ database: AppDatabase) async {
        do {
            try await database.writer.write { db in
                var rng = SystemRandomNumberGenerator()
                try WidgetQueue.refill(db: db, clock: .system, using: &rng)
                try WidgetLog.recordAppReload(reason: "Uygulamada değişiklik", db: db, clock: .system)
            }
        } catch {
            // The widget refills on its own next reload; nothing to surface here.
        }
        WidgetCenter.shared.reloadAllTimelines()
        await PhoneWatchSync.shared.push()
    }

    /// After a settings change that alters the slot grid or the card pool.
    static func rebuild(_ database: AppDatabase) async {
        try? await database.writer.write { db in
            try WidgetQueue.clearFuture(db: db, clock: .system)
        }
        await refresh(database)
    }
}
