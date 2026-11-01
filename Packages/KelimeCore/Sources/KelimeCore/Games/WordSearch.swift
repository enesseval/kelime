import Foundation

/// Kelime Avı: English words hidden in a letter grid, found from their Turkish meanings.
/// Words run left→right, top→bottom or diagonally down-right; never backwards (it's for
/// learning, not for being tricky).
public struct WordSearch: Sendable, Equatable {
    public struct Point: Hashable, Sendable, Codable {
        public var row: Int
        public var col: Int
        public init(row: Int, col: Int) { self.row = row; self.col = col }
    }

    public enum Direction: CaseIterable, Sendable, Codable {
        case across, down, diagonal

        var step: (row: Int, col: Int) {
            switch self {
            case .across: (0, 1)
            case .down: (1, 0)
            case .diagonal: (1, 1)
            }
        }
    }

    public struct Placement: Sendable, Equatable, Identifiable {
        public var card: Card
        /// Upper-case ASCII letters of the word.
        public var letters: [Character]
        public var start: Point
        public var direction: Direction
        public var id: String { card.id }

        public var cells: [Point] {
            let step = direction.step
            return letters.indices.map { Point(row: start.row + step.row * $0, col: start.col + step.col * $0) }
        }
    }

    public let size: Int
    /// `grid[row][col]`.
    public let grid: [[Character]]
    public let placements: [Placement]

    public func letter(at point: Point) -> Character { grid[point.row][point.col] }

    /// The placement whose cells are exactly `cells` (in either order), if any.
    public func placement(matching cells: [Point]) -> Placement? {
        placements.first { $0.cells == cells || $0.cells == cells.reversed() }
    }

    /// Cells on the straight line from `start` to `end` when it is a row, column or 45° line;
    /// otherwise nil. The selection a finger drag makes.
    public static func line(from start: Point, to end: Point) -> [Point]? {
        let dr = end.row - start.row, dc = end.col - start.col
        guard dr == 0 || dc == 0 || abs(dr) == abs(dc) else { return nil }
        let steps = max(abs(dr), abs(dc))
        let sr = dr.signum(), sc = dc.signum()
        return (0...steps).map { Point(row: start.row + sr * $0, col: start.col + sc * $0) }
    }

    /// Builds a grid holding as many of `cards` as fit (up to `wordCount`), longest first, with
    /// random filler letters. Deterministic for a given generator. Nil when fewer than 3 fit.
    public static func make(
        cards: [Card],
        size: Int = 8,
        wordCount: Int = 6,
        using rng: inout some RandomNumberGenerator
    ) -> WordSearch? {
        var grid = [[Character?]](repeating: [Character?](repeating: nil, count: size), count: size)
        var placements: [Placement] = []
        let candidates = cards
            .filter { $0.isSingleWord && $0.word.count >= 3 && $0.word.count <= size }
            .sorted { $0.word.count > $1.word.count }
        for card in candidates where placements.count < wordCount {
            let letters = Array(card.word.uppercased(with: Locale(identifier: "en_US_POSIX")))
            var options: [(Point, Direction)] = []
            for direction in Direction.allCases {
                let step = direction.step
                for row in 0..<size {
                    for col in 0..<size {
                        let endRow = row + step.row * (letters.count - 1)
                        let endCol = col + step.col * (letters.count - 1)
                        guard endRow < size, endCol < size else { continue }
                        var fits = true
                        for i in letters.indices {
                            let existing = grid[row + step.row * i][col + step.col * i]
                            if let existing, existing != letters[i] { fits = false; break }
                        }
                        if fits { options.append((Point(row: row, col: col), direction)) }
                    }
                }
            }
            guard let (start, direction) = options.randomElement(using: &rng) else { continue }
            let placement = Placement(card: card, letters: letters, start: start, direction: direction)
            for (i, cell) in placement.cells.enumerated() { grid[cell.row][cell.col] = letters[i] }
            placements.append(placement)
        }
        guard placements.count >= 3 else { return nil }
        let alphabet = Array("ABCDEFGHIJKLMNOPRSTUVYZ")
        let filled = grid.map { row in row.map { $0 ?? alphabet.randomElement(using: &rng)! } }
        return WordSearch(size: size, grid: filled, placements: placements)
    }
}
