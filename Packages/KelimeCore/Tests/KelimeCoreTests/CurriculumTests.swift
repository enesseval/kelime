import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct CurriculumTests {
    let clock = AppClock.fixed(try! Date("2026-10-13T07:20:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "Europe/Istanbul")!)

    func makeDatabase(_ prefs: Preferences = Preferences(level: .a1, enabledDecks: [.a1])) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try prefs.save(db)
        }
        return db
    }

    @Test func importsTheA1Course() throws {
        let db = try makeDatabase()
        try db.reader.read { db throws in
            let units = try Curriculum.units(level: .a1, db: db)
            #expect(units.count == 10)
            #expect(units.first?.placement == .first && units.last?.placement == .last)
            let allHaveStories = units.allSatisfy { !$0.stories.isEmpty }
            #expect(allHaveStories)
            let cafe = try Curriculum.cards(of: "a1-cafe", db: db)
            #expect(cafe.first?.word == "café")
            #expect(cafe.contains { $0.isPhrase && $0.word == "Here you are." })
            // A shared card sits in both units, stored once.
            #expect(try Curriculum.cards(of: "a1-home", db: db).contains { $0.id == "a1-table" })
            #expect(try Card.filter(key: "a1-table").fetchCount(db) == 1)
            let old = try #require(try Card.fetchOne(db, key: "a1-old"))
            #expect(old.senses?.first?.tr == ["eski"])
            #expect(try Card.fetchOne(db, key: "a1-child")?.note == "Çoğulu: children.")
        }
    }

    @Test func onlyStartedUnitsReachTheWidget() throws {
        let db = try makeDatabase()
        let coreIDs = try db.reader.read { db in Set(try Curriculum.cards(of: "a1-core", db: db).map(\.id)) }
        let cafeOnly = try db.reader.read { db in
            Set(try Curriculum.cards(of: "a1-cafe", db: db).map(\.id)).subtracting(coreIDs)
        }
        var ids = try db.reader.read { db in Set(try CardQueries.candidates(in: [.a1], db: db).map(\.cardID)) }
        #expect(ids == coreIDs) // the core counts as started
        try db.writer.write { db in try Curriculum.start("a1-cafe", db: db) }
        ids = try db.reader.read { db in Set(try CardQueries.candidates(in: [.a1], db: db).map(\.cardID)) }
        #expect(ids == coreIDs.union(cafeOnly))
        let progress = try db.reader.read { db in try Curriculum.progress(level: .a1, db: db) }
        #expect(progress.filter(\.started).map(\.unit.id).sorted() == ["a1-cafe", "a1-core"])
    }

    @Test func startingAUnitSwitchesItsDeckOn() throws {
        let db = try makeDatabase(Preferences(level: .b1))
        try db.writer.write { db in try Curriculum.start("a1-family", db: db) }
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks }.contains(.a1))
    }

    @Test func otherLevelsAreUnaffected() throws {
        let db = try makeDatabase(Preferences())
        let ids = try db.reader.read { db in try CardQueries.candidates(in: DeckID.basicDecks, db: db) }
        #expect(ids.count == 109) // the A2 and B1 cores (always started)
        #expect(!DeckID.basicDecks.contains(.a1))
    }

    func learn(_ fraction: Double, of unitID: String, in db: AppDatabase) throws {
        try db.writer.write { db in
            let cards = try Curriculum.cards(of: unitID, db: db)
            for card in cards.prefix(Int((Double(cards.count) * fraction).rounded(.up))) {
                try CardState(cardID: card.id, state: .learned).save(db)
            }
        }
    }

    @Test func unitsComeInPlanOrder() throws {
        let db = try makeDatabase()
        let state = try #require(try db.reader.read { db in try Curriculum.state(db: db) })
        #expect(state.units.prefix(3).map(\.id) == ["a1-core", "a1-family", "a1-home"])
        #expect(state.units.last?.id == "a1-bridge")
        #expect(state.currentID == "a1-core")
        #expect(state.nextLevel == nil)
    }

    @Test func aNearlyLearnedUnitHandsOver() throws {
        let db = try makeDatabase()
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == nil)
        try learn(0.85, of: "a1-core", in: db)
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == "a1-family")
        let state = try #require(try db.reader.read { db in try Curriculum.state(db: db) })
        #expect(state.currentID == "a1-family")
        #expect(state.units.filter(\.started).map(\.id) == ["a1-core", "a1-family"])
        // Nothing more until the new unit is learned too.
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == nil)
    }

    @Test func handsOverOnce() throws {
        let db = try makeDatabase()
        try db.writer.write { db in _ = try Curriculum.advance(db: db) }
        try learn(0.85, of: "a1-core", in: db)
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == "a1-family")
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == nil)
        #expect(try db.reader.read { db in try Curriculum.state(db: db)?.currentID } == "a1-family")
    }

    @Test func aStartedUnitIsPickedUpBeforeANewOne() throws {
        let db = try makeDatabase()
        try db.writer.write { db in _ = try Curriculum.advance(db: db) }
        try db.writer.write { db in try Curriculum.start("a1-city", db: db) }
        try learn(0.85, of: "a1-core", in: db)
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == "a1-city")
        try learn(0.85, of: "a1-city", in: db)
        try learn(0.85, of: "a1-family", in: db)
        // family is nearly learned without being studied as a unit, so it is skipped.
        #expect(try db.writer.write { db in try Curriculum.advance(db: db) } == "a1-home")
    }

    @Test func theLearnerCanPickTheNextUnit() throws {
        let db = try makeDatabase()
        try db.writer.write { db in try Curriculum.makeCurrent("a1-shopping", db: db) }
        try learn(0.85, of: "a1-core", in: db)
        try db.writer.write { db in _ = try Curriculum.advance(db: db) }
        let state = try #require(try db.reader.read { db in try Curriculum.state(db: db) })
        #expect(state.currentID == "a1-shopping")
    }

    @Test func importsTheA2Course() throws {
        let db = try makeDatabase(Preferences(level: .a2, enabledDecks: [.a2]))
        let state = try #require(try db.reader.read { db in try Curriculum.state(db: db) })
        #expect(state.units.count == 12)
        #expect(state.units.prefix(3).map(\.id) == ["a2-core", "a2-travel", "a2-work"])
        #expect(state.units.last?.id == "a2-bridge")
        let because = try #require(try db.reader.read { db in try Card.fetchOne(db, key: "a2-because") })
        #expect(because.pos == .conjunction)
    }

    @Test func anA2StarterGetsOnlyTheA2Course() throws {
        let db = try makeDatabase(Preferences())
        try db.writer.write { db in try OnboardingChoices(level: .a2).save(db: db) }
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks } == [.a2])
    }

    @Test func examDecksTakeCourseWordsWithoutStartingUnits() throws {
        let db = try makeDatabase(Preferences(level: .a1, enabledDecks: [.a1, .yds], isPro: true))
        let ids = try db.reader.read { db in try CardQueries.candidates(in: [.yds], db: db).map(\.cardID) }
        // "claim" is a YDS word; once B2 is a course its tag sits on b1-claim, in the B1 bridge,
        // which an A1 learner has not started.
        #expect(ids.contains { $0.hasSuffix("-claim") })
        #expect(ids.count > 60)
        // Exam-only cards (words no course teaches) are in the exam deck and in no level deck.
        #expect(ids.contains("exam-hamper"))
        #expect(try db.reader.read { db in try CardQueries.candidates(in: [.a1], db: db).map(\.cardID) }.allSatisfy { $0.hasPrefix("a1-") })
        try db.writer.write { db in try Curriculum.switchLevel(to: .c1, db: db) }
        #expect(try db.reader.read { db in try CardQueries.candidates(in: [.c1], db: db).map(\.cardID) }.allSatisfy { !$0.hasPrefix("exam-") })
    }

    @Test func switchingLevelLeavesOnlyTheNewCourse() throws {
        let db = try makeDatabase(Preferences(level: .a1, enabledDecks: [.a1, .yds], isPro: true))
        try db.writer.write { db in
            var rng = SeededGenerator(seed: 1)
            _ = try WidgetQueue.refill(db: db, clock: clock, using: &rng)
            try Curriculum.switchLevel(to: .b1, db: db)
            try WidgetQueue.clearCurrentAndFuture(db: db, clock: clock)
            _ = try WidgetQueue.refill(db: db, clock: clock, using: &rng)
        }
        try db.reader.read { db throws in
            #expect(try Preferences.load(db).enabledDecks == [.b1, .yds])
            #expect(try Curriculum.state(db: db)?.currentID == "b1-core")
            let current = try #require(try WidgetQueue.current(db: db, clock: clock))
            let card = try #require(try Card.fetchOne(db, key: current.cardID))
            #expect(card.level == .b1 || card.id.hasPrefix("b") || card.id.hasPrefix("c"))
            let levelCards = try CardQueries.candidates(in: [.b1], db: db).map(\.cardID)
            #expect(levelCards.allSatisfy { $0.hasPrefix("b1-") })
        }
    }

    @Test func aFinishedA1OpensA2() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            for unit in try Curriculum.units(level: .a1, db: db) { try Curriculum.start(unit.id, db: db) }
            try Settings.set(.currentUnit, "a1-bridge", in: db)
        }
        try learn(0.85, of: "a1-bridge", in: db)
        let state = try #require(try db.reader.read { db in try Curriculum.state(db: db) })
        #expect(state.nextLevel == .a2)
        try db.writer.write { db in try Curriculum.moveOn(to: .a2, db: db) }
        let a2 = try #require(try db.reader.read { db in try Curriculum.state(db: db) })
        #expect(a2.level == .a2 && a2.currentID == "a2-core")
        #expect(try db.reader.read { db in try Preferences.load(db).enabledDecks } == [.a1, .a2])
    }

    @Test func levelsWithoutUnitsKeepTheirDecks() throws {
        let db = try makeDatabase(Preferences(level: .c1))
        try db.writer.write { db in
            try db.execute(sql: "DELETE FROM unit_card WHERE unit_id LIKE 'c1-%'; DELETE FROM unit WHERE level = 'C1'")
        }
        #expect(try db.reader.read { db in try Curriculum.state(db: db) } == nil)
    }

    @Test func phrasesStayOutOfWritingAndPuzzles() throws {
        let db = try makeDatabase()
        try db.writer.write { db in
            for unit in try Curriculum.units(level: .a1, db: db) { try Curriculum.start(unit.id, db: db) }
        }
        for seed in UInt64(0)..<30 {
            var rng = SeededGenerator(seed: seed)
            let questions = try db.reader.read { db in try QuickReview.makeQuestions(db: db, using: &rng) }
            for q in questions {
                if case .write = q.kind {
                    #expect(q.card.isSingleWord)
                }
                if case .meaning(let options) = q.kind, q.card.isPhrase {
                    let words = try db.reader.read { db in try Card.filter(options.contains(Card.Columns.word)).fetchAll(db) }
                    let allPhrases = words.allSatisfy { $0.isPhrase }
                    #expect(allPhrases)
                }
            }
        }
        let card = try #require(try db.reader.read { db in try Card.fetchOne(db, key: "a1-café") })
        #expect(!card.isSingleWord)
    }
}

struct PhrasePatternTests {
    @Test func selfTestKeepsThePhraseShape() {
        let pattern = SampleContent.phrase.selfTestPattern
        #expect(pattern.first == "Make")
        #expect(pattern.blanks == " ________ __ ____.")
        #expect(SampleContent.reluctant.selfTestPattern == ("r", "________"))
    }
}
