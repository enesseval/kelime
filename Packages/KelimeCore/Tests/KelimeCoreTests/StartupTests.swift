import Foundation
import Testing
@testable import KelimeCore

struct StartupTests {
    @Test func bootstrapImportsContent() async throws {
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("db.sqlite")
        let db = try await AppBootstrap.run(contentURL: TestSupport.bundledCardsURL) {
            try AppDatabase.open(at: url)
        }
        #expect(try db.hasContent())
    }

    @Test func missingContentReportsReadStep() async throws {
        do {
            _ = try await AppBootstrap.run(contentURL: nil) { try AppDatabase.inMemory() }
            Issue.record("Expected a startup error")
        } catch {
            #expect(error.step == .readContent)
        }
    }

    @Test func databaseFailureReportsOpenStep() async throws {
        do {
            _ = try await AppBootstrap.run(contentURL: TestSupport.bundledCardsURL) {
                throw AppConfigError.appGroupUnavailable("group.test")
            }
            Issue.record("Expected a startup error")
        } catch {
            #expect(error.step == .openDatabase)
            #expect(error.message.contains("group.test"))
        }
    }

    @Test func appGroupMatchesXcconfig() throws {
        // The xcconfig drives bundle ids and entitlements; KelimeCore holds the same id as a constant.
        let xcconfig = try String(contentsOf: TestSupport.repoRoot.appendingPathComponent("Config/Shared.xcconfig"), encoding: .utf8)
        let line = try #require(xcconfig.split(separator: "\n").first { $0.hasPrefix("APP_BUNDLE_ID") })
        let value = line.split(separator: "=", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)
        #expect(value == AppConfig.appBundleID)
        #expect(AppConfig.appGroupID == "group.\(value)")
        #expect(AppConfig.widgetBundleID == "\(value).widget")
    }
}
