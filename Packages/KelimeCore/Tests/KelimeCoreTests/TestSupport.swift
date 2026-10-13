import Foundation
@testable import KelimeCore

enum TestSupport {
    /// Repository root, found from this file's location.
    static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // KelimeCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // KelimeCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent()

    static var bundledCardsURL: URL { repoRoot.appendingPathComponent("Content/cards.json") }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kelime-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func card(_ word: String, level: CEFRLevel = .b1, pos: PartOfSpeech = .adjective, tr: [String] = ["anlam"]) -> Card {
        Card(
            id: "\(level.rawValue.lowercased())-\(word)",
            word: word,
            pos: pos,
            level: level,
            tr: tr,
            exampleEN: "This is \(word).",
            exampleTR: "Bu bir örnek."
        )
    }

    static func cardsJSON(version: Int, _ cards: [(Card, [DeckTag])]) throws -> Data {
        try JSONEncoder().encode(CardsFile(contentVersion: version, cards: cards.map { ContentCard(card: $0.0, decks: $0.1) }))
    }
}
