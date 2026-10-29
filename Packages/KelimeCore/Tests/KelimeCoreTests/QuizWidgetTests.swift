import Foundation
import GRDB
import Testing
@testable import KelimeCore

/// The medium quiz widget moves on a minute after an answer; the widget can keep to words or
/// phrases; Quick Review explains close misses; the puzzle summary carries its thumbnail.
struct QuizWidgetTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    let start = try! Date("2026-10-13T07:20:00Z", strategy: .iso8601)

    func clock(_ offset: TimeInterval = 0) -> AppClock {
        .fixed(start.addingTimeInterval(offset), timeZone: istanbul)
    }

    func makeDatabase(_ prefs: Preferences = Preferences()) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try prefs.save(db)
        }
        return db
    }

    func quiz(_ db: AppDatabase, at offset: TimeInterval = 0) throws -> [WidgetSnapshot] {
        var rng = SeededGenerator(seed: 5)
        return try db.writer.write { db in try WidgetTimelineBuilder.quiz(db: db, clock: clock(offset), using: &rng) }
    }

    @Test func answerShowsForAMinuteThenTheNextQuestion() throws {
        let db = try makeDatabase()
        let before = try quiz(db)
        let first = try #require(before.first?.card)
        let second = try #require(before.dropFirst().first?.card)
        #expect(before.first?.quizAnswer == nil)

        let result = try db.writer.write { db in
            try WidgetActions.answerQuiz(cardID: first.id, option: first.word, db: db, clock: clock(10))
        }
        #expect(result == true)

        let after = try quiz(db, at: 20)
        #expect(after[0].card?.id == first.id)
        #expect(after[0].quizAnswer == first.word)
        #expect(after[1].card?.id == second.id)
        #expect(after[1].quizAnswer == nil)
        #expect(after[1].date == start.addingTimeInterval(10 + WidgetTimelineBuilder.quizResultDuration))
        #expect(after.map(\.date) == after.map(\.date).sorted())

        // The brought-forward question can be answered before its slot starts.
        let early = try db.writer.write { db in
            try WidgetActions.answerQuiz(cardID: second.id, option: "nope", db: db, clock: clock(90))
        }
        #expect(early == false)

        // Long after the answer the result is gone and the next open question shows.
        let later = try quiz(db, at: 300)
        #expect(later[0].quizAnswer == nil)
        #expect(later[0].card?.id != first.id && later[0].card?.id != second.id)
    }

    @Test func widgetCanShowOnlyWordsOrOnlyPhrases() throws {
        for content in [WidgetContent.words, .phrases] {
            let db = try makeDatabase(Preferences(widgetContent: content))
            var rng = SeededGenerator(seed: 3)
            let snapshots = try db.writer.write { db in try WidgetTimelineBuilder.build(db: db, clock: clock(), using: &rng) }
            let cards = snapshots.compactMap(\.card)
            #expect(!cards.isEmpty)
            #expect(cards.allSatisfy { $0.isPhrase == (content == .phrases) })
        }
    }

    @Test func contentSettingIsSaved() throws {
        let db = try makeDatabase(Preferences(widgetContent: .phrases))
        let loaded = try db.reader.read { db in try Preferences.load(db) }
        #expect(loaded.widgetContent == .phrases)
    }

    @Test func closeMissesGetAHint() {
        let card = Card(id: "x", word: "woman", pos: .noun, level: .a1, tr: ["kadın"], exampleEN: "", exampleTR: "")
        let question = ReviewQuestion(card: card, kind: .write)
        #expect(question.mistakeHint("women")?.contains("4. harf") == true)
        #expect(question.mistakeHint("wmoan")?.contains("yeri karışmış") == true)
        #expect(question.mistakeHint("woman") == nil)
        #expect(question.mistakeHint("") == nil)
        #expect(question.mistakeHint("wxyzq") == nil)
        #expect(ReviewQuestion.wrongPositions("women", "woman") == [3])
    }

    @Test func puzzleSummaryKeepsItsThumbnail() throws {
        let db = try AppDatabase.inMemory()
        let summary = DailyPuzzleSummary(day: LocalDate(year: 2026, month: 10, day: 13), solved: 1, total: 3, cells: [0: true, 1: false, 9: true])
        try db.writer.write { db in try summary.save(db: db) }
        let loaded = try db.reader.read { db in try DailyPuzzleSummary.load(db: db) }
        #expect(loaded == summary)

        // The old three-part form still reads.
        try db.writer.write { db in try Settings.set(.dailyPuzzleSummary, "2026-10-13|2|5", in: db) }
        let old = try db.reader.read { db in try DailyPuzzleSummary.load(db: db) }
        #expect(old?.solved == 2 && old?.cells.isEmpty == true)
    }
}
