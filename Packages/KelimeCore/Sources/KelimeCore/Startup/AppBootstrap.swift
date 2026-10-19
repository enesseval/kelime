import Foundation

/// The named steps of app startup. A failure reports the step it happened in.
public enum StartupStep: String, Sendable, CaseIterable {
    case openDatabase
    case readContent
    case importContent

    /// Turkish label for the launch and error screens.
    public var title: String {
        switch self {
        case .openDatabase: "Veritabanı açılıyor"
        case .readContent: "İçerik okunuyor"
        case .importContent: "Kelimeler yükleniyor"
        }
    }
}

public struct StartupError: Error, CustomStringConvertible, Sendable {
    public let step: StartupStep
    public let message: String

    public init(step: StartupStep, underlying: any Error) {
        self.step = step
        self.message = String(describing: underlying)
    }

    public var description: String { "\(step.rawValue): \(message)" }
}

/// Opens the shared database and imports content, off the main actor: the bundled file, or a
/// newer one `ContentUpdater` downloaded earlier.
public enum AppBootstrap {
    @concurrent
    public static func run(
        contentURL: URL?,
        downloadedURL: URL? = nil,
        openDatabase: @Sendable () throws -> AppDatabase = { try AppDatabase.openShared() },
        progress: @escaping @Sendable (StartupStep, Double) -> Void = { _, _ in }
    ) async throws(StartupError) -> AppDatabase {
        progress(.openDatabase, 0)
        let database: AppDatabase
        do {
            database = try openDatabase()
        } catch {
            throw StartupError(step: .openDatabase, underlying: error)
        }

        progress(.readContent, 0)
        let data: Data
        do {
            guard let contentURL else { throw CocoaError(.fileNoSuchFile) }
            data = ContentUpdater.newest(bundled: try Data(contentsOf: contentURL), downloadedURL: downloadedURL)
        } catch {
            throw StartupError(step: .readContent, underlying: error)
        }

        do {
            _ = try await ContentImporter.importIfNeeded(data, into: database) { value in
                progress(.importContent, value)
            }
        } catch {
            throw StartupError(step: .importContent, underlying: error)
        }
        return database
    }
}
