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
            try CardState(cardID: "a2-busy", state: .struggling, lastAnsweredOn: LocalDate(year: 2026, month: 10, day: 10)).insert(db)
            try CardState(cardID: "a2-wait", state: .new, timesShown: 2).insert(db)
            try CardState(cardID: "b1-proud", state: .learned).insert(db)
        }
        let ids = try questions(db).map(\.id)
        #expect(Array(ids.prefix(3)) == ["a2-busy", "b1-avoid", "a2-wait"])
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

    @Test func answersCountTowardsTheDailyLimit() throws {
        let db = try makeDatabase()
        let q = try #require(try questions(db).first)
        try db.writer.write { db in
            try LearningStore.record(.answered(correct: true), cardID: q.id, source: .quickReview, clock: clock, sessionID: "abc", db: db)
        }
        #expect(try db.reader.read { db in try QuickReviewLimit.remaining(db: db, clock: clock) } == 0)
    }
}
