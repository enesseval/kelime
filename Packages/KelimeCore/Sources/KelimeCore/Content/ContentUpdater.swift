import CryptoKit
import Foundation

/// What GitHub Pages serves next to `cards.json` (written by `tools/publish_content.py`).
public struct ContentManifest: Codable, Sendable, Equatable {
    public var contentVersion: Int
    /// Shape of `cards.json`. An app that knows an older shape keeps its content until it is
    /// updated from the App Store.
    public var schema: Int
    public var sha256: String
    public var size: Int

    public init(contentVersion: Int, schema: Int, sha256: String, size: Int) {
        self.contentVersion = contentVersion
        self.schema = schema
        self.sha256 = sha256
        self.size = size
    }
}

/// Fetches newer content from GitHub Pages. The bundled content always works offline; a
/// newer download is kept in the App Group and preferred at the next launch.
///
/// Nothing about the learner is sent: two plain GET requests, no cookies, no identifiers.
public enum ContentUpdater {
    public static let schema = 3
    public static let baseURL = URL(string: "https://enesseval.github.io/kelime/content/")!
    public static let checkEvery: TimeInterval = 6 * 60 * 60
    static let fileName = "downloaded-cards.json"

    public enum Outcome: Equatable, Sendable {
        /// Checked recently; nothing fetched.
        case skipped
        case upToDate(version: Int)
        case updated(version: Int)
    }

    public enum UpdateError: Error, Equatable {
        case badResponse
        case checksumMismatch
        case versionMismatch
    }

    public static func downloadedURL(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// The content to import at launch: the downloaded file when it is newer than the bundled
    /// one (an App Store update can bring newer content than an old download).
    public static func newest(bundled: Data, downloadedURL: URL?) -> Data {
        guard let downloadedURL, let downloaded = try? Data(contentsOf: downloadedURL),
              let new = version(of: downloaded), new > (version(of: bundled) ?? 0) else { return bundled }
        return downloaded
    }

    static func version(of data: Data) -> Int? {
        struct Header: Decodable { var contentVersion: Int }
        return try? JSONDecoder().decode(Header.self, from: data).contentVersion
    }

    /// Asks for the manifest at most every `checkEvery`, downloads newer content, checks it,
    /// keeps it in `directory` and imports it. Runs off the main actor.
    @concurrent
    public static func update(
        database: AppDatabase,
        directory: URL,
        now: Date = .now,
        fetch: @Sendable (URL) async throws -> Data = download
    ) async throws -> Outcome {
        let checked = try await database.reader.read { db in try Settings.int(.contentCheckedAt, in: db) }
        if let checked, now.timeIntervalSince1970 - Double(checked) < checkEvery { return .skipped }

        let manifest = try JSONDecoder().decode(ContentManifest.self, from: try await fetch(baseURL.appendingPathComponent("manifest.json")))
        let current = try await database.writer.write { db in
            try Settings.set(.contentCheckedAt, Int(now.timeIntervalSince1970), in: db)
            return try Settings.int(.contentVersion, in: db) ?? 0
        }
        guard manifest.schema <= schema, manifest.contentVersion > current else { return .upToDate(version: current) }

        // The version in the query keeps a cached older file from answering.
        var components = URLComponents(url: baseURL.appendingPathComponent("cards.json"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "v", value: String(manifest.contentVersion))]
        let data = try await fetch(components.url!)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == manifest.size, digest == manifest.sha256 else { throw UpdateError.checksumMismatch }
        guard version(of: data) == manifest.contentVersion else { throw UpdateError.versionMismatch }

        _ = try await ContentImporter.importIfNeeded(data, into: database)
        try data.write(to: downloadedURL(in: directory), options: .atomic)
        return .updated(version: manifest.contentVersion)
    }

    /// A plain GET without cookies or cache.
    @Sendable
    public static func download(_ url: URL) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession(configuration: configuration).data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
        return data
    }
}
