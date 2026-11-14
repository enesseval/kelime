import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct SentenceGamesTests {
    let clock = AppClock.fixed(try! Date("2026-11-14T09:00:00Z", strategy: .iso8601), timeZone: TimeZone(identifier: "Europe/Istanbul")!)

    func card(_ id: String, word: String = "idea", pos: PartOfSpeech = .noun, level: CEFRLevel = .b1,
              en: String, tr: String = "Bir cümle.") -> Card {
        Card(id: id, word: word, pos: pos, level: level, tr: ["anlam"], exampleEN: en, exampleTR: tr)
    }

    func fullDatabase() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in try ContentImporter.apply(file, in: db, progress: { _ in }) }
        return db
    }

    // MARK: Cümle Kur tokens

    @Test func tokensKeepPunctuationAndLowerOnlyTheFirstCapital() {
        let t = SentenceTokens.tokens(card("a", en: "She wants to buy a Car, quickly."))
        #expect(t == ["she", "wants", "to", "buy", "a", "Car,", "quickly."])
        // The cards below show the lowered first word; the row shows place 1 with a capital.
        #expect(SentenceTokens.shown("she", position: 0) == "She")
        #expect(SentenceTokens.shown("she", position: 1) == "she")
        #expect(SentenceTokens.shown("Car,", position: 5) == "Car,")
        #expect(SentenceTokens.sentence(t!) == "She wants to buy a Car, quickly.")
    }

    @Test func pronounIAndAcronymsKeepTheirCapital() {
        #expect(SentenceTokens.tokens(card("a", en: "I think this is good."))?.first == "I")
        #expect(SentenceTokens.tokens(card("b", en: "I'm sure this is fine."))?.first == "I'm")
        #expect(SentenceTokens.tokens(card("c", en: "I'll call you back soon."))?.first == "I'll")
        #expect(SentenceTokens.tokens(card("c2", en: "I\u{2019}ve seen this film."))?.first == "I\u{2019}ve")
        #expect(SentenceTokens.tokens(card("d", en: "It's a very long way."))?.first == "it's")
        #expect(SentenceTokens.tokens(card("e", en: "Ice is cold today."))?.first == "ice")
    }

    @Test func everyOtherWordKeepsItsOwnCasing() {
        #expect(SentenceTokens.tokens(card("a", en: "Can I ask you something?")) == ["can", "I", "ask", "you", "something?"])
        #expect(SentenceTokens.tokens(card("b", en: "I think this is a good idea.")) == ["I", "think", "this", "is", "a", "good", "idea."])
        #expect(SentenceTokens.tokens(card("c", en: "Try this cake. It's very good.")) == ["try", "this", "cake.", "It's", "very", "good."])
        #expect(SentenceTokens.tokens(card("d", en: "We met Ali in London today.")) == ["we", "met", "Ali", "in", "London", "today."])
    }

    @Test func sentenceLengthAndTranslationDecideEligibility() {
        #expect(SentenceTokens.tokens(card("a", en: "Too short here.")) == nil)           // 3 words
        #expect(SentenceTokens.tokens(card("b", en: "Four words are fine."))?.count == 4)
        #expect(SentenceTokens.tokens(card("c", en: "One two three four five six seven eight nine ten."))?.count == 10)
        #expect(SentenceTokens.tokens(card("d", en: "One two three four five six seven eight nine ten eleven.")) == nil)
        #expect(SentenceTokens.tokens(card("e", en: "Four words are fine.", tr: "  ")) == nil)
        #expect(SentenceTokens.tokens(card("f", en: "Go go go go")) == nil)               // one distinct word
        #expect(SentenceTokens.tokens(card("g", en: "  Spaces   between   the words.  "))?.count == 4)
    }

    @Test func shuffleNeverSpellsTheRightOrder() {
        let sentences = [
            "Go go go stop", "A b a b", "No no no no yes", "Yes yes no", "It is what it is.",
            "Very very very good day", "Aa bb aa bb aa bb aa bb",
        ]
        for text in sentences {
            guard let tokens = SentenceTokens.tokens(card("x", en: text)) ?? SentenceTokens.tokens(card("x", en: text + " now")) else { continue }
            for seed in 0..<300 {
                var rng = SeededGenerator(seed: UInt64(seed))
                let order = SentenceTokens.shuffledOrder(tokens, using: &rng)
                #expect(Array(order.sorted()) == Array(tokens.indices))
                #expect(order.map { tokens[$0] } != tokens, Comment(stringLiteral: "seed \(seed): \(text)"))
            }
        }
    }

    @Test func shuffleFallbackStillDiffersWhenOneWordDiffers() {
        // 9 equal words and one different: a random shuffle rarely differs, the fallback must.
        let tokens = Array(repeating: "no", count: 9) + ["yes"]
        for seed in 0..<200 {
            var rng = SeededGenerator(seed: UInt64(seed))
            #expect(SentenceTokens.shuffledOrder(tokens, using: &rng).map { tokens[$0] } != tokens)
        }
    }

    // MARK: Cümle Kur game

    func expectCheck(_ g: inout SentenceGame, _ expected: SentenceCheck?, line: UInt = #line) {
        let result = g.check()
        #expect(result == expected)
    }

    func expectAnswer(_ g: inout GapFillGame, _ option: Int, _ expected: Bool) {
        let result = g.answer(option)
        #expect(result == expected)
    }

    func game(_ en: String = "She wants to buy bread.", seed: UInt64 = 1) -> SentenceGame {
        var rng = SeededGenerator(seed: seed)
        return SentenceGame(cards: [card("one", en: en)], using: &rng)
    }

    /// Puts the tiles in right order.
    func solve(_ g: inout SentenceGame) {
        let item = g.current!
        for position in item.tokens.indices {
            let tile = item.tileOrder.indices.first { !g.placed($0) && item.tileText($0) == item.tokens[position] }!
            g.place(tile)
        }
    }

    /// Puts the tiles in a wrong order (reverse of the right one).
    func scramble(_ g: inout SentenceGame) {
        let item = g.current!
        for tile in item.tileOrder.indices.reversed() where !g.placed(tile) { g.place(tile) }
        // The reverse could be right for a palindrome sentence; make sure it is wrong.
        if g.row.map({ item.tileText($0) }) == item.tokens {
            g.remove(rowPlace: 0)
            g.remove(rowPlace: 0)
            let all = item.tileOrder.indices.filter { !g.placed($0) }
            for t in all.reversed() { g.place(t) }
        }
    }

    @Test func rightOrderOnFirstTryIsCorrect() {
        var g = game()
        #expect(g.canCheck == false)
        solve(&g)
        #expect(g.canCheck)
        expectCheck(&g, .correct)
        #expect(g.solved)
        #expect(g.firstTryCount == 1)
        #expect(g.failedCards.isEmpty)
        expectCheck(&g, nil)
    }

    @Test func wrongThenRightOnSecondTryCountsAsNotCorrect() {
        var g = game()
        scramble(&g)
        guard case .wrong(let places) = g.check() else { Issue.record("expected wrong"); return }
        #expect(!places.isEmpty)
        #expect(g.tries == 1 && !g.revealed && !g.solved)
        // The wrong cards stay; clear the row and put the right order.
        while !g.row.isEmpty { g.remove(rowPlace: 0) }
        solve(&g)
        expectCheck(&g, .correct)
        #expect(g.tries == 2)
        #expect(g.firstTryCount == 0)
        #expect(g.failedCards.map(\.id) == ["one"])
    }

    @Test func secondWrongRevealsTheAnswer() {
        var g = game()
        scramble(&g)
        _ = g.check()
        expectCheck(&g, .revealed)
        #expect(g.revealed)
        #expect(g.failedCards.map(\.id) == ["one"])
        // After revealing no more taps and no more checks.
        g.remove(rowPlace: 0)
        #expect(g.row.count == g.current!.tokens.count)
        expectCheck(&g, nil)
        g.next()
        #expect(g.isFinished)
    }

    @Test func tappingMovesCardsAndEqualWordsAreInterchangeable() {
        var g = game("It is what it is.")
        let item = g.current!
        // The tokens "it", "is", "what", "it", "is." -> only the text matters.
        solve(&g)
        // Swap the two "is"-less equal tokens: build the same texts with the other tile of "it".
        expectCheck(&g, .correct)
        #expect(item.tokens.count == 5)
    }

    @Test func tapsRemoveAndPlaceAndIgnoreDuplicates() {
        var g = game()
        g.place(0)
        g.place(0)
        #expect(g.row == [0])
        g.place(99)
        #expect(g.row == [0])
        g.remove(rowPlace: 5)
        #expect(g.row == [0])
        g.remove(rowPlace: 0)
        #expect(g.row.isEmpty)
        g.next() // not solved: stays
        #expect(g.index == 0)
    }

    @Test func roundIsFiveSentencesAndSkipsUnusableCards() {
        var rng = SeededGenerator(seed: 3)
        var cards = (0..<8).map { card("c\($0)", en: "This is sentence number \($0).") }
        cards.insert(card("bad", en: "Short one."), at: 0)
        let g = SentenceGame(cards: cards, using: &rng)
        #expect(g.items.count == SentenceGame.round)
        #expect(!g.items.contains { $0.card.id == "bad" })
    }

    @Test func answersRecordOnceAtTheEndWithSentenceSource() throws {
        let appDB = try AppDatabase.inMemory()
        let cards = [card("a", en: "This is the first one."), card("b", en: "This is the second one."), card("c", en: "This is the third one.")]
        try appDB.writer.write { db in for c in cards { try c.insert(db) } }
        var rng = SeededGenerator(seed: 5)
        var g = SentenceGame(cards: cards, using: &rng)
        // a: first try right; b: second try right; c: revealed.
        solve(&g); expectCheck(&g, .correct); g.next()
        scramble(&g); _ = g.check(); while !g.row.isEmpty { g.remove(rowPlace: 0) }; solve(&g); expectCheck(&g, .correct); g.next()
        scramble(&g); _ = g.check(); expectCheck(&g, .revealed); g.next()
        #expect(g.isFinished)
        try appDB.writer.write { db in try g.record(seconds: 42, clock: clock, db: db) }
        try appDB.reader.read { db in
            let logs = try ReviewLog.order(Column("id")).fetchAll(db)
            #expect(logs.map(\.cardID) == ["a", "b", "c"])
            #expect(logs.map(\.correct) == [true, false, false])
            #expect(logs.allSatisfy { $0.source == .sentence })
            let row = try Row.fetchOne(db, sql: "SELECT game, score, total, seconds FROM game_result")!
            #expect(row["game"] as String == "sentence")
            #expect(row["score"] as Int == 1)
            #expect(row["total"] as Int == 3)
            #expect(row["seconds"] as Int == 42)
            #expect(try String.fetchOne(db, sql: "SELECT sources FROM streak_day") == "sentence")
        }
    }

    // MARK: Boşluğu Doldur

    @Test func wordMustAppearAsWrittenToBeBlanked() {
        #expect(GapFill.blanked(card("a", word: "think", en: "I think this is a good idea.")) == "I _____ this is a good idea.")
        // Different form, or part of another word, or inside a contraction: out.
        #expect(GapFill.blanked(card("b", word: "think", en: "I thought it was a good idea.")) == nil)
        #expect(GapFill.blanked(card("c", word: "can", en: "I can't see the board.")) == nil)
        #expect(GapFill.blanked(card("d", word: "an", en: "This is a banana.")) == nil)
        #expect(GapFill.blanked(card("e", word: "think", en: "Thinking is hard.")) == nil)
        // Case does not matter, every place is blanked, punctuation next to it is fine.
        #expect(GapFill.blanked(card("f", word: "idea", en: "Idea? What an Idea, idea.")) == "_____? What an _____, _____.")
        #expect(GapFill.blanked(card("g", word: "look after", en: "She will look after the baby.")) == "She will _____ the baby.")
    }

    func poolCards(_ words: [String], pos: PartOfSpeech = .noun, level: CEFRLevel = .b1) -> [Card] {
        words.map { card("p-\($0)", word: $0, pos: pos, level: level, en: "Some \($0) text here.") }
    }

    @Test func distractorsShareposAndLevelAreDistinctAndDifferFromTheAnswer() {
        let target = card("t", word: "idea", en: "I have a good idea about this.")
        var pool = poolCards(["plan", "Plan", "rule", "goal", "idea", "Idea", "tool", "name"])
        pool.append(card("other-pos", word: "quick", pos: .adjective, en: "x y z q"))
        pool.append(card("other-level", word: "river", level: .c1, en: "x y z q"))
        pool.append(card("in-sentence", word: "good", en: "x y z q"))
        pool.append(card("in-sentence2", word: "about", en: "x y z q"))
        for seed in 0..<300 {
            var rng = SeededGenerator(seed: UInt64(seed))
            guard let q = GapFill.question(target, pool: pool, using: &rng) else { Issue.record("no question"); return }
            #expect(q.options.count == 4)
            #expect(Set(q.options.map { $0.lowercased() }).count == 4)
            #expect(q.options[q.answerIndex] == "idea")
            #expect(q.options.filter { $0.lowercased() == "idea" }.count == 1)
            let byWord = Dictionary(grouping: pool + [target], by: \.word)
            for option in q.options where option != "idea" {
                let sources = byWord[option]!
                #expect(sources.contains { $0.pos == .noun && $0.level == .b1 })
                #expect(!["good", "about", "quick", "river"].contains(option))
            }
            #expect(q.sentence == "I have a good _____ about this.")
            #expect(q.translation == "Bir cümle.")
        }
    }

    @Test func fewerThanThreeDistractorsDropsTheCard() {
        let target = card("t", word: "idea", en: "I have a good idea about this.")
        var rng = SeededGenerator(seed: 1)
        #expect(GapFill.question(target, pool: poolCards(["plan", "rule"]), using: &rng) == nil)
        // Duplicates of the same word are one distractor.
        #expect(GapFill.question(target, pool: poolCards(["plan", "Plan", "rule"]), using: &rng) == nil)
        // A card whose word is not in the sentence gives no question however large the pool is.
        let off = card("o", word: "think", en: "I thought so.")
        #expect(GapFill.question(off, pool: poolCards(["plan", "rule", "goal", "tool"]), using: &rng) == nil)
    }

    @Test func distractorPoolFromDatabaseSkipsUserCardsAndTheCardItself() throws {
        let appDB = try AppDatabase.inMemory()
        let cards = [
            card("t", word: "idea", en: "I have a good idea."),
            card("n1", word: "plan", en: "A plan."), card("user-1", word: "mine", en: "x"),
            card("v1", word: "run", pos: .verb, en: "x"), card("n2", word: "rule", level: .c1, en: "x"),
        ]
        try appDB.writer.write { db in for c in cards { try c.insert(db) } }
        let pool = try appDB.reader.read { db in try GapFill.distractorPool(for: cards[0], db: db) }
        #expect(pool.map(\.id) == ["n1"])
    }

    @Test func roundIsSixtySecondsAndOnlyAnsweredQuestionsRecord() throws {
        #expect(GapFillGame.duration == 60)
        #expect(GapFillGame.seconds == 60)
        let appDB = try AppDatabase.inMemory()
        let cards = [
            card("a", word: "plan", en: "We need a plan today."), card("b", word: "rule", en: "That is a rule here."),
            card("c", word: "goal", en: "My goal is clear."), card("d", word: "tool", en: "Use this tool now."),
            card("e", word: "name", en: "Say your name please."),
        ]
        try appDB.writer.write { db in for c in cards { try c.insert(db) } }
        var rng = SeededGenerator(seed: 2)
        let qs = try appDB.reader.read { db in try GapFill.questions(db: db, cards: Array(cards.prefix(3)), using: &rng) }
        #expect(qs.count == 3)
        var g = GapFillGame(questions: qs)
        let first = g.current!
        expectAnswer(&g, first.answerIndex, true)
        expectAnswer(&g, first.answerIndex, false) // counts once
        g.next()
        let second = g.current!
        expectAnswer(&g, (second.answerIndex + 1) % 4, false)
        g.next()
        // The third question is never answered.
        #expect(g.score == 1 && g.answered == 2)
        #expect(g.missedCards.map(\.id) == [second.card.id])
        try appDB.writer.write { db in try g.record(seconds: 60, clock: clock, db: db) }
        try appDB.reader.read { db in
            let logs = try ReviewLog.order(Column("id")).fetchAll(db)
            #expect(logs.count == 2)
            #expect(logs.map(\.correct) == [true, false])
            #expect(logs.allSatisfy { $0.source == .gapFill })
            let row = try Row.fetchOne(db, sql: "SELECT game, score, total, seconds FROM game_result")!
            #expect(row["game"] as String == "gapFill")
            #expect(row["score"] as Int == 1)
            #expect(row["total"] as Int == 2)
            #expect(try GamePool.best(.gapFill, db: db) == 1)
            #expect(try String.fetchOne(db, sql: "SELECT sources FROM streak_day") == "gapFill")
        }
    }

    // MARK: Eligibility sweep over the real content

    @Test func sweepOverAllCardsNeverCrashesAndNeverGivesAnEmptyRound() throws {
        let appDB = try fullDatabase()
        let cards = try appDB.reader.read { db in try Card.fetchAll(db) }
        #expect(cards.count > 2000)

        let sentence = cards.filter { SentenceTokens.usable($0) }
        #expect(sentence.count >= 2100, Comment(stringLiteral: "Cümle Kur: \(sentence.count)"))
        for c in sentence {
            let tokens = SentenceTokens.tokens(c)!
            var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: c.id.hashValue))
            let order = SentenceTokens.shuffledOrder(tokens, using: &rng)
            #expect(order.map { tokens[$0] } != tokens, Comment(stringLiteral: c.id))
            #expect(!SentenceTokens.sentence(tokens).isEmpty)
        }
        for offset in stride(from: 0, to: sentence.count - 12, by: 97) {
            var rng = SeededGenerator(seed: UInt64(offset))
            let g = SentenceGame(cards: Array(sentence[offset..<offset + SentenceGame.pool]), using: &rng)
            #expect(g.items.count == SentenceGame.round)
        }

        var rng = SeededGenerator(seed: 11)
        let questions = try appDB.reader.read { db in try GapFill.questions(db: db, cards: cards, using: &rng) }
        #expect(questions.count >= 1700, Comment(stringLiteral: "Boşluğu Doldur: \(questions.count)"))
        for q in questions {
            #expect(q.sentence.contains(GapFill.blank), Comment(stringLiteral: q.card.id))
            #expect(q.options.count == 4 && Set(q.options.map { $0.lowercased() }).count == 4, Comment(stringLiteral: q.card.id))
            #expect(q.options[q.answerIndex] == q.card.word)
        }
        // A round drawn from the pool has questions.
        let round = Array(questions.prefix(GapFillGame.pool))
        #expect(!GapFillGame(questions: round).isOutOfQuestions)
    }
}
