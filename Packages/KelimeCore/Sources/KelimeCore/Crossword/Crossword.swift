import Foundation

/// A grid position (row, column), zero-based from the top-left.
public struct GridPoint: Hashable, Codable, Sendable, Comparable {
    public var row: Int
    public var col: Int

    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    public static func < (a: GridPoint, b: GridPoint) -> Bool {
        (a.row, a.col) < (b.row, b.col)
    }
}

public enum CrosswordDirection: String, Codable, Sendable {
    case across = "a"
    case down = "d"

    /// Turkish label: Yatay / Dikey.
    public var label: String { self == .across ? "Yatay" : "Dikey" }
}

/// One answer in a crossword.
public struct CrosswordEntry: Codable, Sendable, Hashable, Identifiable {
    public var number: Int
    public var direction: CrosswordDirection
    public var row: Int
    public var col: Int
    /// ASCII uppercase answer, e.g. "HESITATE".
    public var answer: String
    public var cardID: String

    public var id: String { "\(number)\(direction.rawValue)" }
    public var length: Int { answer.count }

    public init(number: Int, direction: CrosswordDirection, row: Int, col: Int, answer: String, cardID: String) {
        self.number = number
        self.direction = direction
        self.row = row
        self.col = col
        self.answer = answer
        self.cardID = cardID
    }

    public var cells: [GridPoint] {
        (0..<answer.count).map { i in
            direction == .across ? GridPoint(row, col + i) : GridPoint(row + i, col)
        }
    }

    public var letters: [Character] { Array(answer) }

    enum CodingKeys: String, CodingKey {
        case number = "n", direction = "dir", row = "r", col = "c", answer, cardID = "card_id"
    }
}

/// A free-form crossword: a set of entries on a width × height grid. Every other cell is a block.
public struct Crossword: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var width: Int
    public var height: Int
    public var entries: [CrosswordEntry]

    public init(id: String, width: Int, height: Int, entries: [CrosswordEntry]) {
        self.id = id
        self.width = width
        self.height = height
        self.entries = entries
    }

    /// Identifies the grid layout, so saved progress is never applied to a different grid
    /// (e.g. after the bundled puzzles are regenerated under the same id).
    public var fingerprint: String {
        entries.map { "\($0.row),\($0.col)\($0.direction.rawValue)\($0.answer)" }.sorted().joined(separator: ";")
    }

    /// Solution letter for every open cell.
    public var solution: [GridPoint: Character] {
        var grid: [GridPoint: Character] = [:]
        for entry in entries {
            for (point, letter) in zip(entry.cells, entry.letters) { grid[point] = letter }
        }
        return grid
    }

    /// Clue numbers by starting cell.
    public var numbers: [GridPoint: Int] {
        Dictionary(entries.map { (GridPoint($0.row, $0.col), $0.number) }, uniquingKeysWith: { a, _ in a })
    }

    /// Entries in clue order: across first, then down, each by number.
    public var orderedEntries: [CrosswordEntry] {
        entries.sorted { ($0.direction == .across ? 0 : 1, $0.number) < ($1.direction == .across ? 0 : 1, $1.number) }
    }

    /// Entries passing through `point`.
    public func entries(at point: GridPoint) -> [CrosswordEntry] {
        entries.filter { $0.cells.contains(point) }
    }
}

/// Structural checks shared by the bundled daily puzzles and the on-device generator.
public enum CrosswordValidator {
    public enum Problem: Equatable, CustomStringConvertible {
        case outOfBounds(String)
        case conflict(GridPoint)
        case touching(GridPoint)
        case blockedEnds(String)
        case parallelOverlap(GridPoint)
        case disconnected
        case badNumbering(String)
        case notLetters(String)

        public var description: String {
            switch self {
            case .outOfBounds(let id): "\(id) leaves the grid"
            case .conflict(let p): "letters disagree at \(p.row),\(p.col)"
            case .touching(let p): "cells touch without a crossing at \(p.row),\(p.col)"
            case .blockedEnds(let id): "\(id) has a letter right before or after it"
            case .parallelOverlap(let p): "two words in the same direction share \(p.row),\(p.col)"
            case .disconnected: "words are not all connected"
            case .badNumbering(let id): "\(id) has the wrong clue number"
            case .notLetters(let id): "\(id) is not A–Z"
            }
        }
    }

    public static func problems(_ puzzle: Crossword) -> [Problem] {
        var problems: [Problem] = []
        var owners: [GridPoint: [CrosswordEntry]] = [:]
        var letters: [GridPoint: Character] = [:]

        for entry in puzzle.entries {
            if !entry.answer.allSatisfy({ ("A"..."Z").contains($0) }) || entry.answer.count < 2 {
                problems.append(.notLetters(entry.id))
            }
            for (point, letter) in zip(entry.cells, entry.letters) {
                guard (0..<puzzle.height).contains(point.row), (0..<puzzle.width).contains(point.col) else {
                    problems.append(.outOfBounds(entry.id)); break
                }
                if let existing = letters[point], existing != letter { problems.append(.conflict(point)) }
                letters[point] = letter
                owners[point, default: []].append(entry)
            }
        }

        for (point, list) in owners {
            if Set(list.map(\.direction)).count < list.count { problems.append(.parallelOverlap(point)) }
        }

        for entry in puzzle.entries {
            let (dr, dc) = entry.direction == .across ? (0, 1) : (1, 0)
            let before = GridPoint(entry.row - dr, entry.col - dc)
            let afterCell = entry.cells.last.map { GridPoint($0.row + dr, $0.col + dc) }
            if letters[before] != nil || afterCell.flatMap({ letters[$0] }) != nil {
                problems.append(.blockedEnds(entry.id))
            }
            // Side neighbours of a cell only this word owns must be empty.
            for point in entry.cells where owners[point]?.count == 1 {
                let sides = entry.direction == .across
                    ? [GridPoint(point.row - 1, point.col), GridPoint(point.row + 1, point.col)]
                    : [GridPoint(point.row, point.col - 1), GridPoint(point.row, point.col + 1)]
                for side in sides where letters[side] != nil {
                    problems.append(.touching(point))
                }
            }
        }

        if !isConnected(puzzle) { problems.append(.disconnected) }

        let expected = numbering(for: puzzle.entries.map { ($0.direction, GridPoint($0.row, $0.col)) }, letters: letters)
        for entry in puzzle.entries where expected[GridPoint(entry.row, entry.col)] != entry.number {
            problems.append(.badNumbering(entry.id))
        }
        return problems
    }

    public static func isValid(_ puzzle: Crossword) -> Bool { problems(puzzle).isEmpty }

    static func isConnected(_ puzzle: Crossword) -> Bool {
        guard let first = puzzle.entries.first else { return true }
        var seen: Set<String> = [first.id]
        var queue = [first]
        while let entry = queue.popLast() {
            let cells = Set(entry.cells)
            for other in puzzle.entries where !seen.contains(other.id) && !cells.isDisjoint(with: other.cells) {
                seen.insert(other.id)
                queue.append(other)
            }
        }
        return seen.count == puzzle.entries.count
    }

    /// Standard numbering: start cells get 1, 2, 3… in reading order.
    static func numbering(for starts: [(CrosswordDirection, GridPoint)], letters: [GridPoint: Character]) -> [GridPoint: Int] {
        let startCells = Set(starts.map(\.1)).sorted()
        return Dictionary(uniqueKeysWithValues: startCells.enumerated().map { ($1, $0 + 1) })
    }
}
