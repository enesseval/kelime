import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct CourseSwitchTests {
    func makeDatabase(_ prefs: Preferences) throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let file = try ContentImporter.decode(Data(contentsOf: TestSupport.bundledCardsURL))
        try db.writer.write { db in
            try ContentImporter.apply(file, in: db, progress: { _ in })
            try prefs.save(db)
        }
        return db
    }

    @Test func courseOffStaysOffAsUnitsStart() throws {
        let db = try makeDatabase(Preferences(level: .a2, enabledDecks: [.a1, .a2, .yds]))
        try db.writer.write { db in
            try DeckQueries.setCourse(false, db: db)
            #expect(try Preferences.load(db).enabledDecks == [.yds])
            let unit = try #require(try Curriculum.units(level: .a2, db: db).last)
            try Curriculum.makeCurrent(unit.id, db: db)
            #expect(try Preferences.load(db).enabledDecks == [.yds])
            #expect(try DeckQueries.courseEnabled(db: db) == false)
            try DeckQueries.setCourse(true, db: db)
            #expect(Set(try Preferences.load(db).enabledDecks) == [.yds, .a1, .a2])
        }
    }
}
