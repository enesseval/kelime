import Foundation
import GRDB

/// The shared SQLite database, used by both the app and the widget extension.
///
/// On device it lives in the App Group container and is opened as a WAL `DatabasePool`, so the
/// app and the widget's App Intents can read and write it concurrently.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    /// Wraps an already opened database and runs pending migrations.
    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Migrations.migrator.migrate(writer)
    }

    public var reader: any DatabaseReader { writer }

    /// Opens (creating if needed) the database in the App Group container.
    public static func openShared() throws -> AppDatabase {
        let directory = try AppConfig.sharedContainerURL()
        return try open(at: directory.appendingPathComponent(AppConfig.databaseFileName))
    }

    /// Opens a WAL database pool at `url` with settings safe for cross-process sharing.
    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let pool = try DatabasePool(path: url.path, configuration: sharedConfiguration())
        return try AppDatabase(pool)
    }

    /// An empty in-memory database with the full schema. For tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: sharedConfiguration()))
    }

    static func sharedConfiguration() -> Configuration {
        var config = Configuration()
        // Another process (app or widget) may hold the write lock briefly.
        config.busyMode = .timeout(5)
        config.foreignKeysEnabled = true
        return config
    }

    /// True once content has been imported at least once.
    public func hasContent() throws -> Bool {
        try reader.read { db in try Card.fetchCount(db) > 0 }
    }
}
