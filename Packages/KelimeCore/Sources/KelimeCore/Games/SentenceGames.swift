import Foundation
import GRDB

/// Cümle Kur (docs/V1_2_PLAN.md §4a): the Turkish sentence on top, the English sentence's words
/// as shuffled cards below; the learner taps them into order. Same rules as Android's
/// `SentenceGames.kt`.
public enum SentenceTokens {
    public static let minWords = 4
    public static let maxWords = 10

    /// The English sentence's words in order, as the cards show them: punctuation stays on the
    /// word it follows, and every other word keeps its own casing and only the first word is lowered ("I" and "I'…" stay).
    /// Nil when the card has no usable sentence: 4 to 10 words, a Turkish translation and at
    /// least two different words, so a shuffle can differ.
    public static func tokens(_ card: Card) -> [String]? {
        if card.exampleTR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        let words = card.exampleEN.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard (minWords...maxWords).contains(words.count) else { return nil }
        let tokens = words.enumerated().map { $0.offset == 0 ? lowerFirst($0.element) : $0.element }
        guard Set(tokens).count >= 2 else { return nil }
        return tokens
    }

    public static func usable(_ card: Card) -> Bool { tokens(card) != nil }

    private static func lowerFirst(_ word: String) -> String {
        guard let first = word.first, first.isUppercase else { return word }
        let rest = word.dropFirst()
        // "I", "I'm", "I'll": the pronoun is always capital.
        if first == "I" && (rest.isEmpty || !(rest.first!.isLetter)) { return word }
        // "TV", "DNA", "McDonald's": a capital past the first letter is part of the word.
        if rest.contains(where: \.isUppercase) { return word }
        return first.lowercased() + rest
    }

    /// What a card shows in row `position`: only the first place is capitalised.
    public static func shown(_ token: String, position: Int) -> String {
        guard position == 0, let first = token.first, first.isLowercase else { return token }
        return first.uppercased() + token.dropFirst()
    }

    /// The finished sentence as written: first word capital, the rest as is.
    public static func sentence(_ tokens: [String]) -> String {
        tokens.enumerated().map { shown($0.element, position: $0.offset) }.joined(separator: " ")
    }

    /// A shuffled order of the word indices that never spells the right sentence (compared as
    /// texts, since two cards may show the same word). Needs at least two different words.
    public static func shuffledOrder(_ tokens: [String], using rng: inout some RandomNumberGenerator) -> [Int] {
        let indices = Array(tokens.indices)
        for _ in 0..<40 {
            let order = indices.shuffled(using: &rng)
            if order.map({ tokens[$0] }) != tokens { return order }
        }
        // Certain fallback: swap two places that show different words.
        var order = indices
        if let j = tokens.indices.first(where: { tokens[$0] != tokens[0] }) { order.swapAt(0, j) }
        return order
    }
}

/// What "Kontrol et" found.
public enum SentenceCheck: Sendable, Equatable {
    case correct
    /// A second try is left; the cards in these row places are in the wrong place.
    case wrong(places: Set<Int>)
    /// The second try failed: the right sentence is shown.
    case revealed
}

/// A round of 5 sentences, two tries each. Pure state; the view only renders it.
public struct SentenceGame: Sendable {
    public static let round = 5
    public static let maxTries = 2
    /// Cards to draw so enough have a usable sentence.
    public static let pool = 12

    public struct Item: Sendable {
        public let card: Card
        public let tokens: [String]
        /// `tileOrder[tile]` is the index into `tokens` that tile shows.
        public let tileOrder: [Int]
        public func tileText(_ tile: Int) -> String { tokens[tileOrder[tile]] }
        public var sentence: String { SentenceTokens.sentence(tokens) }
    }

    public let items: [Item]
    public private(set) var index = 0
    /// Tiles in the row, in row order.
    public private(set) var row: [Int] = []
    public private(set) var tries = 0
    public private(set) var revealed = false
    public private(set) var solved = false
    private var firstTry: [String] = []
    private var failed: [String] = []

    public init(cards: [Card], count: Int = round, using rng: inout some RandomNumberGenerator) {
        var items: [Item] = []
        var seen: Set<String> = []
        for card in cards {
            // Two cards may share a sentence; one round never shows it twice.
            guard items.count < count, let tokens = SentenceTokens.tokens(card), seen.insert(tokens.joined(separator: " ")).inserted else { continue }
            items.append(Item(card: card, tokens: tokens, tileOrder: SentenceTokens.shuffledOrder(tokens, using: &rng)))
        }
        self.items = items
    }

    public var current: Item? { items.indices.contains(index) ? items[index] : nil }
    public var isFinished: Bool { index >= items.count }
    public var firstTryCount: Int { firstTry.count }
    public var firstTryCards: [Card] { items.map(\.card).filter { firstTry.contains($0.id) } }
    public var failedCards: [Card] { items.map(\.card).filter { failed.contains($0.id) } }

    public func placed(_ tile: Int) -> Bool { row.contains(tile) }

    /// Tap a tile below: it moves to the end of the row.
    public mutating func place(_ tile: Int) {
        guard let item = current, !solved, !revealed, item.tokens.indices.contains(tile), !placed(tile) else { return }
        row.append(tile)
    }

    /// Tap a card in the row: it goes back below.
    public mutating func remove(rowPlace: Int) {
        guard !solved, !revealed, row.indices.contains(rowPlace) else { return }
        row.remove(at: rowPlace)
    }

    public var canCheck: Bool {
        guard let item = current else { return false }
        return row.count == item.tokens.count && !solved && !revealed
    }

    /// Checks the row against the sentence, as texts: two equal words may swap places.
    public mutating func check() -> SentenceCheck? {
        guard let item = current, canCheck else { return nil }
        tries += 1
        let wrong = Set(row.indices.filter { item.tileText(row[$0]) != item.tokens[$0] })
        if wrong.isEmpty {
            solved = true
            if tries == 1 { firstTry.append(item.card.id) } else { failed.append(item.card.id) }
            return .correct
        }
        if tries >= Self.maxTries {
            revealed = true
            failed.append(item.card.id)
            return .revealed
        }
        return .wrong(places: wrong)
    }

    /// The next sentence (after a right answer or a shown one).
    public mutating func next() {
        guard solved || revealed else { return }
        index += 1
        row = []
        tries = 0
        solved = false
        revealed = false
    }

    /// First try right: correct; wrong, second try or shown: not correct. The round counts the
    /// day for the streak and is stored as a game result.
    public func record(seconds: Int, clock: AppClock, db: Database) throws {
        for item in items {
            let id = item.card.id
            if firstTry.contains(id) {
                try LearningStore.record(.answered(correct: true), cardID: id, source: .sentence, clock: clock, db: db)
            } else if failed.contains(id) {
                try LearningStore.record(.answered(correct: false), cardID: id, source: .sentence, clock: clock, db: db)
            }
        }
        try GamePool.recordResult(game: .sentence, score: firstTry.count, total: items.count, seconds: seconds, clock: clock, db: db)
    }
}

/// Boşluğu Doldur (docs/V1_2_PLAN.md §4b): the English sentence with the card's word blanked,
/// its Turkish translation small underneath, four choices. A card whose word does not appear in
/// its sentence as written (thought / think) is left out.
public enum GapFill {
    public static let blank = "_____"
    public static let optionCount = 4

    public struct Question: Sendable {
        public let card: Card
        public let sentence: String
        public let translation: String
        public let options: [String]
        public let answerIndex: Int
        public var answer: String { options[answerIndex] }
    }

    /// The word as a whole word: no letter or apostrophe next to it ("can" is not in "can't").
    private static func pattern(_ word: String) -> NSRegularExpression? {
        try? NSRegularExpression(
            pattern: "(?<![\\p{L}'\u{2019}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}'\u{2019}])",
            options: [.caseInsensitive]
        )
    }

    private static func contains(_ re: NSRegularExpression, _ text: String) -> Bool {
        re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The sentence with every occurrence of the word blanked, or nil when it does not occur as written.
    public static func blanked(_ card: Card) -> String? {
        guard !card.word.trimmingCharacters(in: .whitespaces).isEmpty, !card.exampleEN.isEmpty,
              let re = pattern(card.word), contains(re, card.exampleEN) else { return nil }
        return re.stringByReplacingMatches(
            in: card.exampleEN, range: NSRange(card.exampleEN.startIndex..., in: card.exampleEN),
            withTemplate: blank
        )
    }

    public static func usable(_ card: Card) -> Bool { blanked(card) != nil }

    /// Cards that could be this card's wrong choices: same part of speech and level, other
    /// words, never a learner's own card.
    public static func distractorPool(for card: Card, db: Database) throws -> [Card] {
        try Card.fetchAll(
            db,
            sql: "SELECT * FROM card WHERE pos = ? AND level = ? AND id <> ? AND id NOT LIKE ?",
            arguments: [card.pos.rawValue, card.level.rawValue, card.id, UserLists.customPrefix + "%"]
        )
    }

    /// One question; nil when the card is not usable or the pool has fewer than three suitable
    /// words. A choice is the same `pos` and level, distinct, different from the answer and not
    /// already visible in the sentence.
    public static func question(_ card: Card, pool: [Card], using rng: inout some RandomNumberGenerator) -> Question? {
        var patterns: [String: NSRegularExpression?] = [:]
        return question(card, pool: pool, patterns: &patterns, using: &rng)
    }

    /// `patterns` caches one compiled regex per word, so a round compiles each word once.
    private static func question(_ card: Card, pool: [Card], patterns: inout [String: NSRegularExpression?], using rng: inout some RandomNumberGenerator) -> Question? {
        guard let blanked = blanked(card) else { return nil }
        let sentenceLower = card.exampleEN.lowercased()
        var taken: Set<String> = [card.word.lowercased()]
        var wrong: [String] = []
        for candidate in pool.shuffled(using: &rng) {
            let key = candidate.word.lowercased()
            if taken.contains(key) || candidate.pos != card.pos || candidate.level != card.level { continue }
            if patterns[key] == nil { patterns[key] = .some(pattern(candidate.word)) }
            if let re = patterns[key] ?? nil, contains(re, sentenceLower) { continue }
            taken.insert(key)
            wrong.append(candidate.word)
            if wrong.count == optionCount - 1 { break }
        }
        guard wrong.count == optionCount - 1 else { return nil }
        let options = (wrong + [card.word]).shuffled(using: &rng)
        guard let answerIndex = options.firstIndex(of: card.word) else { return nil }
        return Question(card: card, sentence: blanked, translation: card.exampleTR, options: options, answerIndex: answerIndex)
    }

    public static func questions(db: Database, cards: [Card], using rng: inout some RandomNumberGenerator) throws -> [Question] {
        var pools: [String: [Card]] = [:]
        var result: [Question] = []
        var patterns: [String: NSRegularExpression?] = [:]
        // `question` returns nil for a card that is not usable, so each card is checked once here.
        for card in cards {
            let key = card.pos.rawValue + "|" + card.level.rawValue
            if pools[key] == nil { pools[key] = try distractorPool(for: card, db: db) }
            if let q = question(card, pool: pools[key] ?? [], patterns: &patterns, using: &rng) { result.append(q) }
        }
        return result
    }
}

/// A 60-second round of `GapFill` questions, like Eşleştir: right goes green, wrong shows the
/// answer and moves on after a second.
public struct GapFillGame: Sendable {
    public static let duration: TimeInterval = 60
    public static let seconds = 60
    /// Enough questions for a fast player in 60 seconds.
    public static let pool = 40

    public let questions: [GapFill.Question]
    public private(set) var index = 0
    public private(set) var score = 0
    private var results: [(id: String, right: Bool)] = []

    public init(questions: [GapFill.Question]) { self.questions = questions }

    public var current: GapFill.Question? { questions.indices.contains(index) ? questions[index] : nil }
    public var answered: Int { results.count }
    public var isOutOfQuestions: Bool { index >= questions.count }
    public var missedCards: [Card] {
        let missed = Set(results.filter { !$0.right }.map(\.id))
        return questions.map(\.card).filter { missed.contains($0.id) }
    }
    public var rightCards: [Card] {
        let right = Set(results.filter(\.right).map(\.id))
        return questions.map(\.card).filter { right.contains($0.id) }
    }

    /// Right or not for the choice `option` of the current question; it counts once.
    @discardableResult
    public mutating func answer(_ option: Int) -> Bool {
        guard let q = current, !results.contains(where: { $0.id == q.card.id }) else { return false }
        let right = option == q.answerIndex
        results.append((q.card.id, right))
        if right { score += 1 }
        return right
    }

    /// The next question (the view waits a second after a wrong answer).
    public mutating func next() { if index < questions.count { index += 1 } }

    /// Each answered word: correct or not. Questions never answered are not recorded.
    public func record(seconds: Int, clock: AppClock, db: Database) throws {
        for r in results {
            try LearningStore.record(.answered(correct: r.right), cardID: r.id, source: .gapFill, clock: clock, db: db)
        }
        try GamePool.recordResult(game: .gapFill, score: score, total: results.count, seconds: seconds, clock: clock, db: db)
    }
}
