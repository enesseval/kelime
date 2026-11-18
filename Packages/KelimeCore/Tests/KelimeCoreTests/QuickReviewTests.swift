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
        var rng = SeededGenerator(seed: 1)
        let order = try db.reader.read { db in try QuickReview.orderedCardIDs(db: db, using: &rng) }
        #expect(Array(order.prefix(3)) == ["b1-quite", "b1-avoid", "b1-nearly"])
        // The round itself is shuffled, but holds the same first picks.
        let ids = try questions(db).map(\.id)
        #expect(Set(ids).isSuperset(of: order.prefix(3)))
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

struct QuickReviewRotationTests {
    func makeDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        return db
    }

    func strugglingSameDay(_ db: AppDatabase, count: Int) throws -> [String] {
        let ids = try db.reader.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM card WHERE level IN ('A2','B1') ORDER BY id LIMIT \(count)")
        }
        try db.writer.write { db in
            for id in ids {
                try CardState(cardID: id, state: .struggling, lastAnsweredOn: LocalDate(year: 2026, month: 10, day: 13)).insert(db)
            }
        }
        return ids
    }

    /// One round as the app plays it: build, remember, answer every question wrong.
    func playRound(_ db: AppDatabase, rng: inout SeededGenerator, deck: DeckID? = nil) throws -> [String] {
        let ids = try db.reader.read { db in try QuickReview.makeQuestions(db: db, deck: deck, using: &rng) }.map(\.id)
        try db.writer.write { db in try QuickReview.rememberRound(db: db, ids: ids, wrong: Set(ids)) }
        return ids
    }

    @Test func fiveRoundsKeepTheRepeatRules() throws {
        let db = try makeDatabase()
        _ = try strugglingSameDay(db, count: 40)
        var rng = SeededGenerator(seed: 11)
        var previous = try playRound(db, rng: &rng)
        for _ in 0..<4 {
            let round = try playRound(db, rng: &rng)
            #expect(round.count == 10)
            #expect(Set(round.prefix(4)).isDisjoint(with: previous))
            #expect(Set(round).intersection(previous).count <= 3)
            previous = round
        }
    }

    @Test func onlyWrongAnswersComeBack() throws {
        let db = try makeDatabase()
        _ = try strugglingSameDay(db, count: 40)
        var rng = SeededGenerator(seed: 5)
        let first = try db.reader.read { db in try QuickReview.makeQuestions(db: db, using: &rng) }.map(\.id)
        let wrong = Set(first.prefix(2))
        try db.writer.write { db in try QuickReview.rememberRound(db: db, ids: first, wrong: wrong) }
        let second = try db.reader.read { db in try QuickReview.makeQuestions(db: db, using: &rng) }.map(\.id)
        #expect(Set(second).intersection(first).isSubset(of: wrong))
    }

    @Test func sameDayTiesAreShuffledAcrossRounds() throws {
        let db = try makeDatabase()
        _ = try strugglingSameDay(db, count: 20)
        var rng = SeededGenerator(seed: 2)
        let a = try db.reader.read { db in try QuickReview.orderedCardIDs(db: db, using: &rng) }
        let b = try db.reader.read { db in try QuickReview.orderedCardIDs(db: db, using: &rng) }
        #expect(Array(a.prefix(20)) != Array(b.prefix(20)))
    }

    @Test func smallPoolStillGivesAFullRound() throws {
        // A pool of six words: the picker is tested directly.
        let ordered = ["a", "b", "c", "d", "e", "f"]
        var rng = SeededGenerator(seed: 4)
        let round = QuickReview.pickRound(from: ordered, memory: .init(ids: ordered, wrong: Set(ordered)), using: &rng)
        #expect(round.count == 6 && Set(round) == Set(ordered))
        let none = QuickReview.pickRound(from: ordered, memory: .init(ids: ordered, wrong: []), using: &rng)
        #expect(none.count == 6)
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

/// docs/SYNC.md "Hızlı Tekrar: noktalama cevabı ele vermesin (1.3.0)": over all of cards.json,
/// no multiple-choice question gives its answer away by its ending or its capital letter.
struct OptionLeakTests {
    func database() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        return db
    }

    /// What the learner sees: one ending type and, among multi-word options, one capital style.
    func check(_ shown: [String], _ label: String) {
        #expect(Set(shown.map { OptionStyle.ending(of: $0) }).count == 1, "ending leak: \(label) \(shown)")
        let multi = shown.filter { $0.split(separator: " ").count > 1 && $0.first?.isLetter == true }
        if multi.count >= 2 {
            #expect(Set(multi.map { $0.first?.isUppercase ?? false }).count == 1, "capital leak: \(label) \(shown)")
        }
    }

    @Test func quizOptionsOfEveryCardHideTheAnswer() throws {
        let db = try database()
        var rng = SeededGenerator(seed: 7)
        let cards = try db.reader.read { try Card.fetchAll($0) }
        try db.reader.read { db in
            for count in [4, 2] {
                for card in cards {
                    let options = try CardQueries.quizOptions(for: card, optionCount: count, db: db, using: &rng)
                    #expect(options.count == count && Set(options).count == count, "\(card.id)")
                    // The values stay the real words.
                    #expect(options.contains(card.word), "\(card.id)")
                    check(OptionStyle.display(options), "\(card.id) x\(count)")
                }
            }
        }
    }

    @Test func matchBoardShowsOneStyle() throws {
        let db = try database()
        let cards = try db.reader.read { try Card.fetchAll($0) }.filter(\.isPhrase).prefix(40)
        let game = MatchGame(cards: Array(cards), seed: 3)
        let shown = game.english.compactMap { $0?.text }
        check(shown, "match english")
        check(game.turkish.compactMap { $0?.text }, "match turkish")
        // Taps still work on the real cards.
        var g = game
        let en = g.english[0]!
        let tr = g.turkish.compactMap { $0 }.first { $0.card.id == en.card.id }!
        g.tap(en)
        #expect(g.tap(tr) == .match(en.card))
    }

    @Test func differentEndingsAreStrippedAndValuesKept() {
        let options = ["What happened?", "Go home.", "Hello!", "I think…"]
        let shown = OptionStyle.display(options)
        #expect(shown == ["What happened", "Go home", "Hello", "I think"])
        #expect(OptionStyle.display(["Take care!", "I'm moving to…", "look up", "Good luck."]).allSatisfy { $0.first?.isUppercase == true })
        #expect(OptionStyle.display(["Monday", "tree", "river"]) == ["Monday", "tree", "river"])
    }
}
