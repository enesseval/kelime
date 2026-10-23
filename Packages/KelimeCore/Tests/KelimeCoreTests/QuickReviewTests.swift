import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct QuickReviewTests {
    let clock = AppClock.fixed(try! Date("2026-10-14T09:00:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "Europe/Istanbul")!)

    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        return db
    }

    func questions(_ db: AppDatabase, seed: UInt64 = 1) throws -> [ReviewQuestion] {
        var rng = SeededGenerator(seed: seed)
        return try db.reader.read { db in try QuickReview.makeQuestions(db: db, using: &rng) }
    }

    @Test func tenQuestionsFromEntitledDecks() throws {
        let qs = try questions(try makeDatabase())
        #expect(qs.count == 10)
        #expect(Set(qs.map(\.id)).count == 10)
        #expect(qs.allSatisfy { [CEFRLevel.a2, .b1].contains($0.card.level) })
    }

    @Test func orderIsStrugglingThenShownNewThenNew() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            try CardState(cardID: "b1-avoid", state: .struggling, lastAnsweredOn: LocalDate(year: 2026, month: 10, day: 12)).insert(db)
            try CardState(cardID: "b1-quite", state: .struggling, lastAnsweredOn: LocalDate(year: 2026, month: 10, day: 10)).insert(db)
            try CardState(cardID: "b1-nearly", state: .new, timesShown: 2).insert(db)
            try CardState(cardID: "b1-proud", state: .learned).insert(db)
        }
        let ids = try questions(db).map(\.id)
        #expect(Array(ids.prefix(3)) == ["b1-quite", "b1-avoid", "b1-nearly"])
        #expect(!ids.contains("b1-proud"))
    }

    @Test func learnedWordsFillShortDecks() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            for id in try String.fetchAll(db, sql: "SELECT id FROM card WHERE level IN ('A2','B1')") {
                try CardState(cardID: id, state: .learned).insert(db)
            }
        }
        #expect(try questions(db).count == 10)
    }

    @Test func questionKindsAndOptions() throws {
        let qs = try questions(try makeDatabase(), seed: 3)
        for (i, q) in qs.enumerated() {
            switch q.kind {
            case .meaning(let options):
                #expect(options.count == 4)
                #expect(options.contains(q.card.word))
                #expect(Set(options).count == 4)
            case .write:
                #expect(i % 3 == 1)
                #expect(q.card.word.count <= QuickReview.maxWriteLength)
            }
        }
        #expect(qs.contains { if case .write = $0.kind { true } else { false } })
    }

    @Test func blankedSentenceAndAnswerCheck() {
        let q = ReviewQuestion(card: SampleContent.hesitate, kind: .write)
        #expect(q.blankedSentence == "Don't ________ to ask.")
        #expect(q.isCorrect("HESITATE"))
        #expect(q.isCorrect("hesitate "))
        #expect(!q.isCorrect("hesitat"))
        // Device-locale uppercasing must not matter: Turkish "i" → "İ" would break this.
        let reliable = ReviewQuestion(card: SampleContent.reliable, kind: .write)
        #expect(reliable.isCorrect("reliable"))
        #expect(ReviewQuestion.asciiUpper("reliable") == "RELIABLE")
        let pursue = ReviewQuestion(card: Card(id: "b2-pursue", word: "pursue", pos: .verb, level: .b2, tr: ["x"], exampleEN: "Pursue your dreams.", exampleTR: "y"), kind: .write)
        #expect(pursue.blankedSentence == "________ your dreams.")
    }

    @Test func sessionFlowAndSummary() {
        let qs = [SampleContent.reluctant, SampleContent.reliable, SampleContent.hesitate].map { ReviewQuestion(card: $0, kind: .write) }
        var s = ReviewSession(id: "s", questions: qs)
        #expect(s.current?.id == "b2-reluctant")
        s.record(correct: true, before: .new, after: .learned)
        s.record(correct: false, before: .new, after: .struggling) // ignored until advance
        #expect(s.awaitingContinue && s.results.count == 1)
        s.advance()
        s.record(correct: false, before: .new, after: .struggling)
        s.advance()
        s.record(correct: true, before: .struggling, after: .struggling)
        s.advance()
        #expect(s.isFinished && s.current == nil)
        #expect(s.score == 2)
        #expect(s.newlyLearned.map(\.word) == ["reluctant"])
        #expect(s.newlyStruggling.map(\.word) == ["reliable"])
        #expect(s.progress == 1)
    }
}

struct PlacementTestTests {
    @Test func everyLevelHasTwoQuestionsWithFourMeanings() throws {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        var rng = SeededGenerator(seed: 3)
        let questions = try db.reader.read { db in try PlacementTest.questions(db: db, using: &rng) }
        #expect(Set(questions.keys) == Set(CEFRLevel.allCases))
        for (_, list) in questions {
            #expect(list.count == 2)
            for q in list {
                #expect(q.options.count == 4 && Set(q.options).count == 4 && q.options.contains(q.answer))
            }
        }
    }

    @Test func stopsAfterTwoMissedLevelsAndPicksTheHighestKnown() {
        let all = CEFRLevel.allCases
        #expect(PlacementTest.nextLevel(after: [], available: all) == .a1)
        #expect(PlacementTest.nextLevel(after: [(.a1, 2), (.a2, 2)], available: all) == .b1)
        #expect(PlacementTest.nextLevel(after: [(.a1, 2), (.a2, 2), (.b1, 1), (.b2, 0)], available: all) == nil)
        #expect(PlacementTest.result([(.a1, 2), (.a2, 2), (.b1, 1), (.b2, 0)], available: all) == .a2)
        // One miss, then a known level: it goes on, and a lucky high level still counts.
        #expect(PlacementTest.nextLevel(after: [(.a1, 2), (.a2, 1), (.b1, 2)], available: all) == .b2)
        #expect(PlacementTest.result([(.a1, 0), (.a2, 0)], available: all) == .a1)
        #expect(PlacementTest.result([(.a1, 2), (.a2, 2), (.b1, 2), (.b2, 2), (.c1, 2), (.c2, 2)], available: all) == .c2)
    }
}
