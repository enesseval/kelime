import Foundation
import GRDB

/// The daily puzzle for a level with units: made from the units the learner has started, with
/// their struggling words placed first. Levels without units keep the bundled puzzles.
///
/// The grid is made once a day and kept (`<daily key>-grid`), so it does not change while the
/// learner learns words or starts a unit during the day.
public enum CoursePuzzle {
    static func gridKey(level: CEFRLevel, day: LocalDate) -> String {
        DailyPuzzle.key(level: level, day: day) + "-grid"
    }

    /// The kept grid for `day`, if one was made.
    public static func stored(level: CEFRLevel, day: LocalDate, db: Database) throws -> Crossword? {
        guard let row = try PuzzleProgress.fetchOne(db, key: gridKey(level: level, day: day)) else { return nil }
        return try? JSONDecoder().decode(Crossword.self, from: Data(row.cells.utf8))
    }

    /// Today's grid: the kept one, or a fresh one (the same one `keepToday` stores).
    public static func daily(level: CEFRLevel, day: LocalDate, db: Database) throws -> Crossword? {
        try stored(level: level, day: day, db: db) ?? make(level: level, day: day, db: db)
    }

    /// Makes today's grid and keeps it, if the learner's level has units. Runs with every widget
    /// refresh; does nothing once today's grid exists.
    public static func keepToday(clock: AppClock, db: Database) throws {
        let level = try Preferences.load(db).level
        let day = clock.today
        guard try CurriculumUnit.filter(Column("level") == level).fetchCount(db) > 0,
              try stored(level: level, day: day, db: db) == nil,
              let puzzle = try make(level: level, day: day, db: db) else { return }
        let text = String(decoding: try JSONEncoder().encode(puzzle), as: UTF8.self)
        try PuzzleProgress(puzzleKey: gridKey(level: level, day: day), cells: text).insert(db)
    }

    /// Single words from the started units of `level`; up to four struggling ones are seeds.
    static func make(level: CEFRLevel, day: LocalDate, db: Database) throws -> Crossword? {
        let started = try Curriculum.started(db: db)
        var pool: [Card] = []
        var seen = Set<String>()
        for unit in try Curriculum.units(level: level, db: db) where started.contains(unit.id) {
            for card in try Curriculum.cards(of: unit.id, db: db) where seen.insert(card.id).inserted {
                if card.isSingleWord && (3...CrosswordGenerator.maxSize).contains(card.word.count) { pool.append(card) }
            }
        }
        let ids = Set(pool.map(\.id))
        let seeds = try WidgetTimelineBuilder.strugglingCards(db: db, limit: 200)
            .filter { ids.contains($0.id) }
            .prefix(4)
        let seedIDs = Set(seeds.map(\.id))
        return CrosswordGenerator.generate(
            id: "course-\(level.rawValue)-\(day.string)",
            seeds: seeds.map(CrosswordGenerator.Word.init(card:)),
            fillers: pool.filter { !seedIDs.contains($0.id) }.map(CrosswordGenerator.Word.init(card:)),
            seed: UInt64(bitPattern: Int64(day.dayIndex)) &* 2654435761 &+ 7
        )
    }
}
