import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct ArchiveQuotaTests {
    func d(_ s: String) -> LocalDate { LocalDate(string: s)! }

    @Test func weeksStartOnMonday() {
        // 2026-11-16 is a Monday.
        #expect(d("2026-11-16").weekStart == d("2026-11-16"))
        #expect(d("2026-11-17").weekStart == d("2026-11-16"))
        #expect(d("2026-11-22").weekStart == d("2026-11-16")) // Sunday
        #expect(d("2026-11-23").weekStart == d("2026-11-23"))
        #expect(d("2026-11-14").weekStart == d("2026-11-09")) // Saturday
        #expect(d("2026-01-01").weekStart == d("2025-12-29")) // across the year
    }

    @Test func freeLearnersGetTwoAWeek() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            let today = d("2026-11-18")
            #expect(try ArchiveQuota.remaining(today: today, db: db) == 2)
            #expect(try ArchiveQuota.open(d("2026-11-10"), today: today, isPro: false, db: db))
            #expect(try ArchiveQuota.remaining(today: today, db: db) == 1)
            #expect(try ArchiveQuota.open(d("2026-11-11"), today: today, isPro: false, db: db))
            #expect(try ArchiveQuota.remaining(today: today, db: db) == 0)
            // The third is refused and nothing is recorded.
            #expect(try !ArchiveQuota.canOpen(d("2026-11-12"), today: today, isPro: false, db: db))
            #expect(try !ArchiveQuota.open(d("2026-11-12"), today: today, isPro: false, db: db))
            #expect(try ArchiveQuota.opened(today: today, db: db) == ["2026-11-10", "2026-11-11"])
        }
    }

    @Test func openingTheSamePuzzleAgainIsFree() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            let today = d("2026-11-18")
            for _ in 0..<5 { #expect(try ArchiveQuota.open(d("2026-11-10"), today: today, isPro: false, db: db)) }
            #expect(try ArchiveQuota.remaining(today: today, db: db) == 1)
            try ArchiveQuota.open(d("2026-11-11"), today: today, isPro: false, db: db)
            #expect(try ArchiveQuota.open(d("2026-11-10"), today: today, isPro: false, db: db)) // already opened
        }
    }

    @Test func aPuzzlePlayedBeforeOpensWithoutSpending() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            let today = d("2026-11-18")
            try ArchiveQuota.open(d("2026-11-10"), today: today, isPro: false, db: db)
            try ArchiveQuota.open(d("2026-11-11"), today: today, isPro: false, db: db)
            #expect(try ArchiveQuota.open(d("2026-11-05"), today: today, isPro: false, played: true, db: db))
            #expect(try ArchiveQuota.canOpen(d("2026-11-05"), today: today, isPro: false, played: true, db: db))
            #expect(try ArchiveQuota.opened(today: today, db: db).count == 2)
        }
    }

    @Test func theQuotaRenewsOnMonday() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            let sunday = d("2026-11-22")
            try ArchiveQuota.open(d("2026-11-10"), today: sunday, isPro: false, db: db)
            try ArchiveQuota.open(d("2026-11-11"), today: sunday, isPro: false, db: db)
            #expect(try ArchiveQuota.remaining(today: sunday, db: db) == 0)
            let monday = d("2026-11-23")
            #expect(try ArchiveQuota.remaining(today: monday, db: db) == 2)
            #expect(try ArchiveQuota.open(d("2026-11-12"), today: monday, isPro: false, db: db))
            #expect(try ArchiveQuota.opened(today: monday, db: db) == ["2026-11-12"])
            // The old week's puzzles count again only inside their own week.
            #expect(try ArchiveQuota.opened(today: sunday, db: db).isEmpty)
        }
    }

    @Test func proIsUnlimitedAndRecordsNothing() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            let today = d("2026-11-18")
            for n in 1...10 {
                #expect(try ArchiveQuota.open(d("2026-11-\(String(format: "%02d", n))"), today: today, isPro: true, db: db))
            }
            #expect(try ArchiveQuota.remaining(today: today, db: db) == 2)
            #expect(try ArchiveQuota.canOpen(d("2026-11-01"), today: today, isPro: true, db: db))
        }
    }

    @Test func aProgressResetDoesNotRefillTheQuota() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            let today = d("2026-11-18")
            try ArchiveQuota.open(d("2026-11-10"), today: today, isPro: false, db: db)
            try ProgressReset.reset(db: db)
            #expect(try ArchiveQuota.remaining(today: today, db: db) == 1)
        }
    }
}

struct ReadOnlyListsTests {
    @Test func listsAfterTheFirstAreReadOnlyForFreeUsersButNotLost() throws {
        let db = try AppDatabase.inMemory()
        let (first, second, third) = try db.writer.write { db throws -> (UserList, UserList, UserList) in
            try ProEntitlement.cache(true, db: db) // the trial
            let a = try UserLists.create(title: "Bir", isPro: true, now: Date(timeIntervalSince1970: 1), db: db)
            let b = try UserLists.create(title: "İki", isPro: true, now: Date(timeIntervalSince1970: 2), db: db)
            let c = try UserLists.create(title: "Üç", isPro: true, now: Date(timeIntervalSince1970: 3), db: db)
            try UserLists.addCustom(word: "boarding pass", meaning: "biniş kartı", pos: .phrase, level: .a2, to: b.id, db: db)
            return (a, b, c)
        }
        try db.writer.write { db throws in
            // The trial runs: everything is editable.
            #expect(try !UserLists.isReadOnly(second.id, isPro: true, db: db))
            // The trial ends.
            try ProEntitlement.cache(false, db: db)
            #expect(try !UserLists.isReadOnly(first.id, isPro: false, db: db))
            #expect(try UserLists.isReadOnly(second.id, isPro: false, db: db))
            #expect(try UserLists.isReadOnly(third.id, isPro: false, db: db))
            #expect(throws: UserListError.readOnly) { try UserLists.rename(second.id, to: "Yeni", db: db) }
            #expect(throws: UserListError.readOnly) {
                try UserLists.addCustom(word: "ticket", meaning: "bilet", pos: .noun, level: .a1, to: third.id, db: db)
            }
            // Nothing is deleted: the words are still there, and the first list still edits.
            #expect(try UserLists.cards(of: second.id, db: db).count == 1)
            let card = try UserLists.cards(of: second.id, db: db)[0]
            #expect(throws: UserListError.readOnly) { try UserLists.remove(cardID: card.id, from: second.id, db: db) }
            try UserLists.rename(first.id, to: "Bir!", db: db)
            // Deleting stays possible; Pro opens editing again.
            try ProEntitlement.cache(true, db: db)
            try UserLists.rename(second.id, to: "Yeni", db: db)
        }
    }

    @Test func importedListsAreNeverReadOnly() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db throws in
            try UserLists.create(title: "Bir", isPro: false, db: db)
            let imported = try UserLists.import(SharedList(title: "Arkadaştan", cards: [SampleContent.happy]), db: db)
            #expect(try !UserLists.isReadOnly(imported.id, isPro: false, db: db))
            try UserLists.rename(imported.id, to: "Yeniden", db: db)
        }
    }
}

struct FreeGameOrderTests {
    @Test func nextFreeGameFollowsTheOrder() {
        #expect(FreeGame.next(playedToday: []) == .wordSearch)
        #expect(FreeGame.next(playedToday: [.wordSearch]) == .match)
        #expect(FreeGame.next(playedToday: [.match]) == .wordSearch)
        #expect(FreeGame.next(playedToday: [.wordSearch, .match]) == .wordSearch)
    }
}
