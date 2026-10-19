import CryptoKit
import Foundation
import Testing
@testable import KelimeCore

struct ContentUpdaterTests {
    let reluctant = TestSupport.card("reluctant", level: .b2)
    let borrow = TestSupport.card("borrow", level: .a2, pos: .verb)

    func manifest(for data: Data, version: Int, schema: Int = ContentUpdater.schema) throws -> Data {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return try JSONEncoder().encode(ContentManifest(contentVersion: version, schema: schema, sha256: digest, size: data.count))
    }

    /// Serves `manifest.json` and `cards.json` from memory.
    func server(manifest: Data, cards: Data) -> @Sendable (URL) async throws -> Data {
        { url in url.lastPathComponent == "manifest.json" ? manifest : cards }
    }

    func setUp(version: Int) async throws -> (AppDatabase, URL) {
        let db = try AppDatabase.inMemory()
        _ = try await ContentImporter.importIfNeeded(try TestSupport.cardsJSON(version: version, [(reluctant, [.general])]), into: db)
        return (db, try TestSupport.temporaryDirectory())
    }

    @Test func downloadsNewerContentAndPrefersItAtLaunch() async throws {
        let (db, dir) = try await setUp(version: 1)
        let newer = try TestSupport.cardsJSON(version: 2, [(reluctant, [.general]), (borrow, [.general])])
        let outcome = try await ContentUpdater.update(database: db, directory: dir, fetch: server(manifest: try manifest(for: newer, version: 2), cards: newer))
        #expect(outcome == .updated(version: 2))
        #expect(try await db.reader.read { db in try Card.fetchOne(db, key: "a2-borrow") } != nil)

        // The next launch reads the bundled v1 and the download; the download wins.
        let bundled = try TestSupport.cardsJSON(version: 1, [(reluctant, [.general])])
        let chosen = ContentUpdater.newest(bundled: bundled, downloadedURL: ContentUpdater.downloadedURL(in: dir))
        #expect(ContentUpdater.version(of: chosen) == 2)
        // An App Store update with newer bundled content wins over an old download.
        let v3 = try TestSupport.cardsJSON(version: 3, [(reluctant, [.general])])
        #expect(ContentUpdater.version(of: ContentUpdater.newest(bundled: v3, downloadedURL: ContentUpdater.downloadedURL(in: dir))) == 3)
    }

    @Test func checksAtMostEverySixHours() async throws {
        let (db, dir) = try await setUp(version: 1)
        let same = try TestSupport.cardsJSON(version: 1, [(reluctant, [.general])])
        let fetch = server(manifest: try manifest(for: same, version: 1), cards: same)
        let now = Date()
        #expect(try await ContentUpdater.update(database: db, directory: dir, now: now, fetch: fetch) == .upToDate(version: 1))
        #expect(try await ContentUpdater.update(database: db, directory: dir, now: now.addingTimeInterval(3600), fetch: fetch) == .skipped)
        #expect(try await ContentUpdater.update(database: db, directory: dir, now: now.addingTimeInterval(7 * 3600), fetch: fetch) == .upToDate(version: 1))
    }

    @Test func rejectsATamperedFile() async throws {
        let (db, dir) = try await setUp(version: 1)
        let newer = try TestSupport.cardsJSON(version: 2, [(borrow, [.general])])
        let other = try TestSupport.cardsJSON(version: 2, [(reluctant, [.yds])])
        await #expect(throws: ContentUpdater.UpdateError.checksumMismatch) {
            try await ContentUpdater.update(database: db, directory: dir, fetch: server(manifest: try manifest(for: newer, version: 2), cards: other))
        }
        #expect(try await db.reader.read { db in try Settings.int(.contentVersion, in: db) } == 1)
        #expect(!FileManager.default.fileExists(atPath: ContentUpdater.downloadedURL(in: dir).path))
    }

    @Test func skipsContentForANewerAppVersion() async throws {
        let (db, dir) = try await setUp(version: 1)
        let newer = try TestSupport.cardsJSON(version: 2, [(borrow, [.general])])
        let outcome = try await ContentUpdater.update(
            database: db, directory: dir,
            fetch: server(manifest: try manifest(for: newer, version: 2, schema: ContentUpdater.schema + 1), cards: newer))
        #expect(outcome == .upToDate(version: 1))
    }

    @Test func olderContentNeverReplacesNewer() async throws {
        let (db, _) = try await setUp(version: 2)
        let older = try TestSupport.cardsJSON(version: 1, [(borrow, [.general])])
        #expect(try await ContentImporter.importIfNeeded(older, into: db) == .upToDate(version: 1))
        #expect(try await db.reader.read { db in try Card.fetchOne(db, key: "b2-reluctant") } != nil)
    }
}
