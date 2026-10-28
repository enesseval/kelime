import Foundation

/// The playable state of a crossword: typed letters, cursor, hints. Pure and Codable, so it can
/// be saved to `puzzle_progress` and unit-tested.
public struct CrosswordGame: Sendable, Equatable {
    public let puzzle: Crossword
    public private(set) var typed: [GridPoint: Character] = [:]
    /// Cells filled by "Harf aç" or "Kelimeyi göster".
    public private(set) var revealed: Set<GridPoint> = []
    /// Cells marked wrong by "Kelimeyi kontrol et", until retyped.
    public private(set) var wrong: Set<GridPoint> = []
    /// Entries the user needed help with; they become struggling.
    public private(set) var helped: Set<String> = []
    public private(set) var hintsUsed = 0
    public private(set) var activeEntryID: String
    public private(set) var cursor: GridPoint

    private let solution: [GridPoint: Character]

    public init(puzzle: Crossword) {
        self.puzzle = puzzle
        solution = puzzle.solution
        let first = puzzle.playOrder.first!
        activeEntryID = first.id
        cursor = first.cells[0]
    }

    public var activeEntry: CrosswordEntry {
        puzzle.entries.first { $0.id == activeEntryID }!
    }

    public func isSolved(_ entry: CrosswordEntry) -> Bool {
        entry.cells.allSatisfy { typed[$0] == solution[$0] }
    }

    public var isComplete: Bool { puzzle.entries.allSatisfy(isSolved) }
    public var solvedCount: Int { puzzle.entries.filter(isSolved).count }

    /// Entries solved without any help, in clue order.
    public var unaidedEntries: [CrosswordEntry] {
        puzzle.orderedEntries.filter { isSolved($0) && !helped.contains($0.id) }
    }

    // MARK: - Input

    /// Types a letter at the cursor and moves to the next editable cell of the active word.
    /// Letters are stored ASCII-uppercased.
    public mutating func type(_ letter: Character) {
        let upper = Character(ReviewQuestion.asciiUpper(String(letter)))
        guard ("A"..."Z").contains(upper) else { return }
        if !isLocked(cursor) {
            typed[cursor] = upper
            wrong.remove(cursor)
        }
        moveCursor(by: 1)
    }

    /// Clears the cursor cell, or steps back and clears the previous one when it is empty.
    public mutating func deleteBackward() {
        if typed[cursor] != nil, !isLocked(cursor) {
            typed[cursor] = nil
            wrong.remove(cursor)
            return
        }
        moveCursor(by: -1)
        if !isLocked(cursor) {
            typed[cursor] = nil
            wrong.remove(cursor)
        }
    }

    /// Tapping a cell selects it; tapping the cursor again switches direction at a crossing.
    /// At a crossing with a solved word, the unsolved one is chosen: there is nothing left to do
    /// in a solved word.
    public mutating func select(_ point: GridPoint) {
        let options = puzzle.entries(at: point)
        guard !options.isEmpty else { return }
        let unsolved = options.filter { !isSolved($0) }
        let activeHere = options.contains { $0.id == activeEntryID }
        if point == cursor, options.count > 1, let other = options.first(where: { $0.id != activeEntryID }), unsolved.count != 1 {
            activeEntryID = other.id
        } else if !activeHere || (isSolved(activeEntry) && !unsolved.isEmpty) {
            let pick = unsolved.first { $0.direction == .across } ?? unsolved.first ?? options.first { $0.direction == .across } ?? options[0]
            activeEntryID = pick.id
        }
        cursor = point
        // A locked cell (solved crossing or revealed) takes no letters: start at the first open one.
        if isLocked(point), !isSolved(activeEntry), let open = activeEntry.cells.first(where: { !isLocked($0) && typed[$0] == nil }) ?? activeEntry.cells.first(where: { !isLocked($0) }) {
            cursor = open
        }
    }

    /// Next (or previous) unsolved word by number; stays put when everything is solved.
    public mutating func step(_ delta: Int) {
        let ordered = puzzle.playOrder
        guard var index = ordered.firstIndex(where: { $0.id == activeEntryID }) else { return }
        for _ in 0..<ordered.count {
            index = (index + delta + ordered.count) % ordered.count
            if !isSolved(ordered[index]) { break }
        }
        focus(ordered[index])
    }

    public mutating func focus(_ entry: CrosswordEntry) {
        activeEntryID = entry.id
        cursor = entry.cells.first { typed[$0] == nil } ?? entry.cells[0]
    }

    // MARK: - Hints (each marks the word struggling)

    /// "Harf aç": reveals the cursor cell, or the first empty/wrong cell of the word.
    @discardableResult
    public mutating func revealLetter() -> CrosswordEntry {
        let entry = activeEntry
        let target = typed[cursor] == solution[cursor] && entry.cells.contains(cursor)
            ? entry.cells.first { typed[$0] != solution[$0] }
            : cursor
        if let target, let letter = solution[target] {
            typed[target] = letter
            revealed.insert(target)
            wrong.remove(target)
            if target == cursor { moveCursor(by: 1) }
        }
        markHelped(entry)
        return entry
    }

    /// "Kelimeyi kontrol et": marks wrong letters. Returns whether an error showed (which
    /// counts as help).
    @discardableResult
    public mutating func checkWord() -> Bool {
        let entry = activeEntry
        let errors = entry.cells.filter { typed[$0] != nil && typed[$0] != solution[$0] }
        wrong.formUnion(errors)
        if !errors.isEmpty { markHelped(entry) }
        return !errors.isEmpty
    }

    /// "Kelimeyi göster": fills the whole word and moves on to the next unsolved one.
    @discardableResult
    public mutating func revealWord() -> CrosswordEntry {
        let entry = activeEntry
        for cell in entry.cells where typed[cell] != solution[cell] {
            typed[cell] = solution[cell]
            revealed.insert(cell)
            wrong.remove(cell)
        }
        markHelped(entry)
        if !isComplete { step(1) }
        return entry
    }

    private mutating func markHelped(_ entry: CrosswordEntry) {
        hintsUsed += 1
        helped.insert(entry.id)
    }

    /// Revealed cells and cells of solved words can't be edited.
    public func isLocked(_ point: GridPoint) -> Bool {
        revealed.contains(point) || puzzle.entries(at: point).contains { isSolved($0) }
    }

    private mutating func moveCursor(by delta: Int) {
        let cells = activeEntry.cells
        guard let index = cells.firstIndex(of: cursor) else { return }
        var i = index + delta
        while cells.indices.contains(i) {
            if delta < 0 || !isLocked(cells[i]) { cursor = cells[i]; return }
            i += delta
        }
        if delta > 0 && isSolved(activeEntry) && !isComplete { step(1) }
    }

    // MARK: - Persistence

    public struct Snapshot: Codable, Sendable, Equatable {
        public var typed: [String: String]
        public var revealed: [String]
        public var wrong: [String]
        public var helped: [String]
        public var hintsUsed: Int
        /// `Crossword.fingerprint` of the grid this was saved for. Nil in saves from build 2 and earlier.
        public var grid: String?
    }

    private static func key(_ p: GridPoint) -> String { "\(p.row),\(p.col)" }
    private static func point(_ key: String) -> GridPoint? {
        let parts = key.split(separator: ",").compactMap { Int($0) }
        return parts.count == 2 ? GridPoint(parts[0], parts[1]) : nil
    }

    public var snapshot: Snapshot {
        Snapshot(
            typed: Dictionary(uniqueKeysWithValues: typed.map { (Self.key($0), String($1)) }),
            revealed: revealed.map(Self.key).sorted(),
            wrong: wrong.map(Self.key).sorted(),
            helped: helped.sorted(),
            hintsUsed: hintsUsed,
            grid: puzzle.fingerprint
        )
    }

    public init(puzzle: Crossword, snapshot: Snapshot) {
        self.init(puzzle: puzzle)
        for (k, v) in snapshot.typed {
            if let p = Self.point(k), let ch = v.first, solution[p] != nil { typed[p] = ch }
        }
        revealed = Set(snapshot.revealed.compactMap(Self.point).filter { solution[$0] != nil })
        wrong = Set(snapshot.wrong.compactMap(Self.point).filter { solution[$0] != nil })
        helped = Set(snapshot.helped)
        hintsUsed = snapshot.hintsUsed
        if let next = puzzle.playOrder.first(where: { !isSolved($0) }) { focus(next) }
    }

    public func encodedSnapshot() throws -> String {
        String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
    }

    public static func decodeSnapshot(_ text: String) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: Data(text.utf8))
    }
}
