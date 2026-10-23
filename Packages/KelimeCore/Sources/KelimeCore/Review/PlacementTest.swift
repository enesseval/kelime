import Foundation
import GRDB

/// One placement question: an English word with four Turkish meanings to choose from.
public struct PlacementQuestion: Sendable, Equatable, Identifiable {
    public var card: Card
    public var options: [String]
    public var id: String { card.id }

    public var answer: String { card.meaning }
}

/// The optional placement test of onboarding: two words per level from A1 up. A level counts
/// as known when both its words are; the test stops after two levels in a row that are not
/// known, and the result is the highest known level (or A1).
public enum PlacementTest {
    public static let perLevel = 2

    /// Questions per level, in level order. Words are single course words with clear meanings;
    /// wrong options are meanings of other words at the same level.
    public static func questions(db: Database, using rng: inout some RandomNumberGenerator) throws -> [CEFRLevel: [PlacementQuestion]] {
        var result: [CEFRLevel: [PlacementQuestion]] = [:]
        for level in CEFRLevel.allCases {
            let cards = try Card.fetchAll(db, sql: """
                SELECT c.* FROM card c
                WHERE c.level = ? AND c.pos <> 'phrase'
                  AND EXISTS (SELECT 1 FROM unit_card uc WHERE uc.card_id = c.id)
                """, arguments: [level]).filter(\.isSingleWord)
            guard cards.count >= perLevel + 3 else { continue }
            let picked = Array(cards.shuffled(using: &rng).prefix(perLevel))
            result[level] = picked.map { card in
                let wrong = cards.filter { $0.id != card.id && $0.meaning != card.meaning }
                    .shuffled(using: &rng)
                    .prefix(3)
                    .map(\.meaning)
                return PlacementQuestion(card: card, options: ([card.meaning] + wrong).shuffled(using: &rng))
            }
        }
        return result
    }

    /// The next level to ask after `scores` (correct answers per level asked so far), or nil
    /// when the test is over.
    public static func nextLevel(after scores: [(CEFRLevel, Int)], available: [CEFRLevel]) -> CEFRLevel? {
        let misses = scores.suffix(2).filter { $0.1 < perLevel }.count
        if scores.count >= 2 && misses == 2 { return nil }
        let asked = Set(scores.map(\.0))
        return available.sorted().first { !asked.contains($0) }
    }

    /// The highest level answered fully, among the levels the learner can start.
    public static func result(_ scores: [(CEFRLevel, Int)], available: [CEFRLevel]) -> CEFRLevel {
        let known = scores.filter { $0.1 >= perLevel }.map(\.0).max() ?? .a1
        return available.filter { $0 <= known }.max() ?? available.min() ?? .a1
    }
}
