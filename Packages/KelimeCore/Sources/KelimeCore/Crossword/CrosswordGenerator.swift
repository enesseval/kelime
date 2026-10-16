import Foundation

/// Builds free-form crosswords on device (the Pro personal puzzle).
///
/// Words cross only on matching letters, no letter cells touch unless they cross, and the cells
/// right before and after each word stay empty. The result fits in 10 × 10 and holds at least 6
/// words (aiming for 7). Deterministic for a given seed.
public enum CrosswordGenerator {
    public static let maxSize = 10
    public static let minWords = 6
    public static let targetWords = 7
    public static let attempts = 40
    /// Upper bound when extra fillers are needed to give a seed something to cross.
    public static let maxWords = 9

    public struct Word: Sendable, Hashable {
        public var answer: String
        public var cardID: String
        /// Normalized Turkish meanings. Two words sharing one would get the same clue, so a puzzle
        /// never holds both (e.g. develop and improve, both "geliştirmek").
        public var meanings: Set<String>

        public init(answer: String, cardID: String, meanings: Set<String> = []) {
            self.answer = answer
            self.cardID = cardID
            self.meanings = meanings
        }

        public init(card: Card) {
            self.init(answer: ReviewQuestion.asciiUpper(card.word), cardID: card.id, meanings: Card.normalizedMeanings(card.tr))
        }
    }

    /// Tries up to 40 times with all seeds, then falls back to 3 seeds, then 2.
    /// Returns nil only if even 2 seeds can't be placed.
    public static func generate(
        id: String,
        seeds: [Word],
        fillers: [Word],
        seed: UInt64
    ) -> Crossword? {
        var rng = SeededGenerator(seed: seed)
        let usableSeeds = Array(seeds.filter { (2...maxSize).contains($0.answer.count) }.prefix(4))
        let usableFillers = fillers.filter { (3...maxSize).contains($0.answer.count) }
        var seedCounts = [usableSeeds.count]
        for fallback in [3, 2] where fallback < usableSeeds.count { seedCounts.append(fallback) }
        if usableSeeds.isEmpty { seedCounts = [0] }

        for count in seedCounts {
            let chosen = Array(usableSeeds.prefix(count))
            for _ in 0..<attempts {
                if let puzzle = attempt(id: id, seeds: chosen, fillers: usableFillers, using: &rng) {
                    return puzzle
                }
            }
        }
        return nil
    }

    /// Same as `generate`, but reports which seed count succeeded (for tests and telemetry-free stats).
    static func attempt(id: String, seeds: [Word], fillers: [Word], using rng: inout SeededGenerator) -> Crossword? {
        var board = Board(size: maxSize)
        let seedOrder = seeds.shuffled(using: &rng).sorted { $0.answer.count > $1.answer.count }
        var placedIDs = Set<String>()
        var placedAnswers = Set<String>()
        var placedMeanings = Set<String>()

        // First word: across, roughly centered.
        guard let first = seedOrder.first ?? fillers.randomElement(using: &rng) else { return nil }
        let startRow = Int.random(in: 3...6, using: &rng)
        let startCol = Int.random(in: 0...(maxSize - first.answer.count), using: &rng)
        board.place(first, row: startRow, col: startCol, direction: .across)
        placedIDs.insert(first.cardID)
        placedAnswers.insert(first.answer)
        placedMeanings.formUnion(first.meanings)

        // Seeds that can't cross anything yet wait for fillers to give them a letter to hang on.
        // A seed whose meaning duplicates an earlier seed is dropped rather than failing the puzzle.
        var pending: [Word] = []
        for seed in seedOrder.dropFirst() where seed.meanings.isDisjoint(with: placedMeanings.union(pending.flatMap(\.meanings))) {
            pending.append(seed)
        }
        func placePending() {
            var progress = true
            while progress {
                progress = false
                for (i, word) in pending.enumerated() {
                    if let spot = board.bestPlacement(for: word, using: &rng) {
                        board.place(word, row: spot.row, col: spot.col, direction: spot.direction)
                        placedIDs.insert(word.cardID)
                        placedAnswers.insert(word.answer)
                        placedMeanings.formUnion(word.meanings)
                        pending.remove(at: i)
                        progress = true
                        break
                    }
                }
            }
        }
        placePending()

        for word in fillers.shuffled(using: &rng) {
            if pending.isEmpty && board.placed.count >= targetWords { break }
            if board.placed.count >= maxWords { break }
            guard !placedIDs.contains(word.cardID), !placedAnswers.contains(word.answer),
                  word.meanings.isDisjoint(with: placedMeanings),
                  word.meanings.isDisjoint(with: pending.flatMap(\.meanings))
            else { continue }
            if let spot = board.bestPlacement(for: word, using: &rng) {
                board.place(word, row: spot.row, col: spot.col, direction: spot.direction)
                placedIDs.insert(word.cardID)
                placedAnswers.insert(word.answer)
                placedMeanings.formUnion(word.meanings)
                placePending()
            }
        }

        guard pending.isEmpty else { return nil }
        guard board.placed.count >= minWords else { return nil }
        return board.crossword(id: id)
    }

    struct Placement {
        var row: Int
        var col: Int
        var direction: CrosswordDirection
        var crossings: Int
    }

    struct Board {
        let size: Int
        var cells: [Character?]
        /// For each cell, the directions of words through it.
        var owners: [[CrosswordDirection]]
        var placed: [(word: Word, row: Int, col: Int, direction: CrosswordDirection)] = []

        init(size: Int) {
            self.size = size
            cells = Array(repeating: nil, count: size * size)
            owners = Array(repeating: [], count: size * size)
        }

        func letter(_ r: Int, _ c: Int) -> Character? {
            guard r >= 0, c >= 0, r < size, c < size else { return nil }
            return cells[r * size + c]
        }

        mutating func place(_ word: Word, row: Int, col: Int, direction: CrosswordDirection) {
            for (i, ch) in word.answer.enumerated() {
                let (r, c) = direction == .across ? (row, col + i) : (row + i, col)
                cells[r * size + c] = ch
                owners[r * size + c].append(direction)
            }
            placed.append((word, row, col, direction))
        }

        /// Number of crossings if `word` can go at (row, col), else nil.
        func check(_ word: Word, row: Int, col: Int, direction: CrosswordDirection) -> Int? {
            let letters = Array(word.answer)
            let (dr, dc) = direction == .across ? (0, 1) : (1, 0)
            let endR = row + dr * (letters.count - 1), endC = col + dc * (letters.count - 1)
            guard row >= 0, col >= 0, endR < size, endC < size else { return nil }
            if letter(row - dr, col - dc) != nil || letter(endR + dr, endC + dc) != nil { return nil }

            var crossings = 0
            for (i, ch) in letters.enumerated() {
                let r = row + dr * i, c = col + dc * i
                if let existing = letter(r, c) {
                    guard existing == ch, !owners[r * size + c].contains(direction) else { return nil }
                    crossings += 1
                } else {
                    // An empty cell's side neighbours must be empty, or words would touch.
                    if letter(r - dc, c - dr) != nil || letter(r + dc, c + dr) != nil { return nil }
                }
            }
            return crossings > 0 && crossings < letters.count ? crossings : nil
        }

        /// A random placement among those with the most crossings.
        func bestPlacement(for word: Word, using rng: inout SeededGenerator) -> Placement? {
            var options: [Placement] = []
            let letters = Array(word.answer)
            for r in 0..<size {
                for c in 0..<size {
                    guard let existing = letter(r, c) else { continue }
                    for (i, ch) in letters.enumerated() where ch == existing {
                        if let n = check(word, row: r, col: c - i, direction: .across) {
                            options.append(Placement(row: r, col: c - i, direction: .across, crossings: n))
                        }
                        if let n = check(word, row: r - i, col: c, direction: .down) {
                            options.append(Placement(row: r - i, col: c, direction: .down, crossings: n))
                        }
                    }
                }
            }
            guard let most = options.map(\.crossings).max() else { return nil }
            let best = options.filter { $0.crossings == most }
            return best.randomElement(using: &rng)
        }

        /// Crops to the used area and numbers the entries in reading order.
        func crossword(id: String) -> Crossword {
            var minR = size, minC = size, maxR = 0, maxC = 0
            for r in 0..<size {
                for c in 0..<size where letter(r, c) != nil {
                    minR = min(minR, r); minC = min(minC, c); maxR = max(maxR, r); maxC = max(maxC, c)
                }
            }
            let starts = Set(placed.map { GridPoint($0.row - minR, $0.col - minC) }).sorted()
            let numberOf = Dictionary(uniqueKeysWithValues: starts.enumerated().map { ($1, $0 + 1) })
            let entries = placed.map { item in
                let start = GridPoint(item.row - minR, item.col - minC)
                return CrosswordEntry(
                    number: numberOf[start]!,
                    direction: item.direction,
                    row: start.row,
                    col: start.col,
                    answer: item.word.answer,
                    cardID: item.word.cardID
                )
            }
            return Crossword(id: id, width: maxC - minC + 1, height: maxR - minR + 1, entries: entries)
        }
    }
}
