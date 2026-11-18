import Foundation
import GRDB

/// One Quick Review question.
public struct ReviewQuestion: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        /// Turkish meaning → pick the English word from 4 options.
        case meaning(options: [String])
        /// Turkish meaning + sentence with a blank → type the word; the first letter is given.
        case write
    }

    public var card: Card
    public var kind: Kind
    public var id: String { card.id }

    public var kicker: String {
        switch kind {
        case .meaning: "BU KELİMENİN İNGİLİZCESİ"
        case .write: "KELİMEYİ YAZ"
        }
    }

    /// The example sentence with the word replaced by a blank: "She was ________ to leave."
    public var blankedSentence: String {
        let sentence = card.exampleEN
        guard let range = sentence.range(of: card.word, options: [.caseInsensitive]) else { return sentence }
        return sentence.replacingCharacters(in: range, with: String(repeating: "_", count: 8))
    }

    /// Whether `answer` is correct. Letters compare with ASCII uppercasing, never the device
    /// locale (Turkish would turn "i" into "İ").
    public func isCorrect(_ answer: String) -> Bool {
        Self.asciiUpper(answer.trimmingCharacters(in: .whitespaces)) == Self.asciiUpper(card.word)
    }

    /// What went wrong in a typed answer, in Turkish, when it was close: one letter off, two
    /// letters swapped, a few letters off. Nil when it was right, empty or not close.
    public func mistakeHint(_ answer: String) -> String? {
        let typed = Array(Self.asciiUpper(answer.trimmingCharacters(in: .whitespaces)))
        let word = Array(Self.asciiUpper(card.word))
        guard !typed.isEmpty, typed != word, typed.count == word.count else { return nil }
        let wrong = Self.wrongPositions(answer, card.word)
        if wrong.count == 2, wrong[1] == wrong[0] + 1, typed[wrong[0]] == word[wrong[1]], typed[wrong[1]] == word[wrong[0]] {
            return "Çok yakındın: \(wrong[0] + 1). ve \(wrong[1] + 1). harfin yeri karışmış."
        }
        if wrong.count == 1, let index = wrong.first {
            let got = String(typed[index]).lowercased(), want = String(word[index]).lowercased()
            return "Çok yakındın: yalnızca \(index + 1). harf yanlış, \"\(got)\" değil \"\(want)\"."
        }
        if wrong.count * 2 <= word.count {
            return "Yakındın: \(wrong.count) harf yanlış."
        }
        return nil
    }

    /// Indexes where `answer` and `word` differ, compared letter by letter (ASCII uppercased).
    public static func wrongPositions(_ answer: String, _ word: String) -> [Int] {
        let typed = Array(asciiUpper(answer.trimmingCharacters(in: .whitespaces)))
        let target = Array(asciiUpper(word))
        return target.indices.filter { $0 >= typed.count || typed[$0] != target[$0] }
    }

    public static func asciiUpper(_ text: String) -> String {
        text.uppercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

/// Builds and scores Quick Review sessions.
public enum QuickReview {
    public static let questionCount = 10
    public static let optionCount = 4
    /// Longest word asked as a write question; longer words would not fit the letter boxes.
    public static let maxWriteLength = 9

    /// Card ids in study order: struggling (least recently answered first), learned words due
    /// for review, new words the widget has shown, other new words, then other learned words.
    /// Quick Review and the games draw from this.
    public static func orderedCardIDs(
        db: Database,
        deck: DeckID? = nil,
        today: LocalDate? = nil,
        using rng: inout some RandomNumberGenerator
    ) throws -> [String] {
        let prefs = try Preferences.load(db)
        let source: SQL?
        if let deck {
            source = CardQueries.deckFilter([deck])
        } else {
            source = try CardQueries.sourceFilter(prefs.entitledDecks, db: db)
        }
        guard let filter = source else { return [] }
        let rows = try Row.fetchAll(db, SQLRequest<Row>("""
            SELECT c.id, COALESCE(s.state, 'new') AS state, COALESCE(s.times_shown, 0) AS shown,
                   s.last_answered_on AS answered, COALESCE(s.correct_streak, 0) AS streak
            FROM card c LEFT JOIN card_state s ON s.card_id = c.id
            WHERE \(filter)
            """))

        var struggling: [(String, String)] = [], due: [(String, String)] = [], shownNew: [String] = [], otherNew: [String] = [], learned: [(String, String)] = []
        for row in rows {
            let id: String = row["id"]
            let answered: String = row["answered"] ?? ""
            switch LearningState(rawValue: row["state"]) ?? .new {
            case .struggling: struggling.append((id, answered))
            case .new: if (row["shown"] as Int) > 0 { shownNew.append(id) } else { otherNew.append(id) }
            case .learned:
                if let today, let last = LocalDate(string: answered),
                   SpacedReview.isDue(CardState(cardID: id, state: .learned, correctStreak: row["streak"], lastAnsweredOn: last), on: today) {
                    due.append((id, answered))
                } else {
                    learned.append((id, answered))
                }
            }
        }
        // Least recently answered first within the ordered groups; shuffle within the new groups.
        // `last_answered_on` is a day, so words answered on the same day tie: shuffle first, then
        // sort by day (the sort keeps the shuffled order of ties).
        func byDay(_ items: [(String, String)]) -> [String] {
            let shuffled = items.shuffled(using: &rng)
            return shuffled.enumerated().sorted { ($0.element.1, $0.offset) < ($1.element.1, $1.offset) }.map(\.element.0)
        }
        let ordered: [String] = byDay(struggling)
            + byDay(due)
            + shownNew.shuffled(using: &rng)
            + otherNew.shuffled(using: &rng)
            + byDay(learned)
        return ordered
    }

    /// The previous round: its card ids, and which of them were answered wrong.
    public struct RoundMemory: Sendable, Equatable {
        public var ids: [String]
        public var wrong: Set<String>
        public init(ids: [String] = [], wrong: Set<String> = []) {
            self.ids = ids
            self.wrong = wrong
        }
    }

    /// Most cards of the last round that may come back, and positions at the start of a round
    /// they may not take.
    public static let maxRepeats = 3
    public static let protectedStart = 4

    public static func lastRound(db: Database) throws -> RoundMemory {
        func split(_ raw: String?) -> [String] { (raw ?? "").split(separator: ",").map(String.init) }
        return RoundMemory(ids: split(try Settings.string(.lastReviewRound, in: db)),
                           wrong: Set(split(try Settings.string(.lastReviewWrong, in: db))))
    }

    /// Stores the round just built (and which of its cards were answered wrong so far), so the
    /// next round can avoid it. Survives relaunch.
    public static func rememberRound(db: Database, ids: [String], wrong: Set<String>) throws {
        try Settings.set(.lastReviewRound, ids.joined(separator: ","), in: db)
        try Settings.set(.lastReviewWrong, ids.filter { wrong.contains($0) }.joined(separator: ","), in: db)
    }

    /// Chooses and orders one round from the study order: at most 3 cards of the last round
    /// (only ones answered wrong), none in the first 4 positions, the rest shuffled. A pool too
    /// small for that fills up with last-round cards anyway.
    static func pickRound(from ordered: [String], memory: RoundMemory, using rng: inout some RandomNumberGenerator) -> [String] {
        let last = Set(memory.ids)
        var fresh: [String] = [], carried: [String] = [], skippedWrong: [String] = [], skippedOther: [String] = []
        for id in ordered {
            guard fresh.count + carried.count < questionCount else { break }
            if !last.contains(id) {
                fresh.append(id)
            } else if memory.wrong.contains(id) {
                if carried.count < maxRepeats { carried.append(id) } else { skippedWrong.append(id) }
            } else {
                skippedOther.append(id)
            }
        }
        // Small pool: the loop ended without 10; let last-round cards fill the gap.
        for id in skippedWrong + skippedOther where fresh.count + carried.count < questionCount {
            carried.append(id)
        }
        // Fresh cards fill the front; carried ones go into random later slots.
        var result = fresh.shuffled(using: &rng)
        let total = result.count + carried.count
        let slots = Array(min(protectedStart, total)..<max(total, min(protectedStart, total)))
        var chosen = Set(slots.shuffled(using: &rng).prefix(carried.count))
        // Too few late slots (tiny pool): the rest take the earliest free ones.
        var early = 0
        while chosen.count < carried.count {
            if !chosen.contains(early) { chosen.insert(early) }
            early += 1
        }
        var carriedLeft = carried.shuffled(using: &rng)[...]
        var merged: [String] = []
        for position in 0..<total {
            if chosen.contains(position), let next = carriedLeft.popFirst() {
                merged.append(next)
            } else {
                merged.append(result.removeFirst())
            }
        }
        return merged
    }

    /// Picks up to 10 cards: struggling first, then new words the widget has already shown,
    /// then other new words; learned words only if the deck runs short.
    /// `deck` limits the round to one deck (the exam plan's review); nil uses the widget's sources.
    /// With `today`, learned words due for review (see `SpacedReview`) come right after the
    /// struggling ones.
    public static func makeQuestions(
        db: Database,
        deck: DeckID? = nil,
        today: LocalDate? = nil,
        using rng: inout some RandomNumberGenerator
    ) throws -> [ReviewQuestion] {
        let ordered = try orderedCardIDs(db: db, deck: deck, today: today, using: &rng)
        let memory = try lastRound(db: db)
        let ids = pickRound(from: ordered, memory: memory, using: &rng)
        let cards = Dictionary(uniqueKeysWithValues: try Card.fetchAll(db, keys: ids).map { ($0.id, $0) })

        var questions: [ReviewQuestion] = []
        for (index, id) in ids.enumerated() {
            guard let card = cards[id] else { continue }
            if index % 3 == 1 && card.isSingleWord && card.word.count <= maxWriteLength {
                questions.append(ReviewQuestion(card: card, kind: .write))
            } else {
                let options = try CardQueries.quizOptions(for: card, optionCount: optionCount, db: db, using: &rng)
                questions.append(ReviewQuestion(card: card, kind: .meaning(options: options)))
            }
        }
        return questions
    }
}

/// The running state of one session. Pure: the app records answers through `LearningStore`
/// and feeds the resulting states back in.
public struct ReviewSession: Sendable {
    public struct Result: Sendable, Equatable {
        public var card: Card
        public var correct: Bool
        public var before: LearningState
        public var after: LearningState
    }

    public let id: String
    public let questions: [ReviewQuestion]
    public private(set) var index = 0
    public private(set) var results: [Result] = []

    public init(id: String = UUID().uuidString, questions: [ReviewQuestion]) {
        self.id = id
        self.questions = questions
    }

    public var current: ReviewQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    public var isFinished: Bool { index >= questions.count }
    /// Answered the current question but not yet moved on.
    public var awaitingContinue: Bool { results.count > index }
    public var progress: Double { questions.isEmpty ? 1 : Double(results.count) / Double(questions.count) }

    public mutating func record(correct: Bool, before: LearningState, after: LearningState) {
        guard let question = current, !awaitingContinue else { return }
        results.append(Result(card: question.card, correct: correct, before: before, after: after))
    }

    public mutating func advance() {
        guard awaitingContinue else { return }
        index += 1
    }

    public var score: Int { results.filter(\.correct).count }

    /// Words that moved to Öğrenildi during this session.
    public var newlyLearned: [Card] {
        results.filter { $0.after == .learned && $0.before != .learned }.map(\.card)
    }

    /// Words that moved to (or stayed in) Zorlanılan because of a wrong answer.
    public var newlyStruggling: [Card] {
        results.filter { !$0.correct && $0.after == .struggling }.map(\.card)
    }
}
