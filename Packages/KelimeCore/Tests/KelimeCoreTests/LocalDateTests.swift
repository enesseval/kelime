import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct LocalDateTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    let newYork = TimeZone(identifier: "America/New_York")!

    func calendar(_ tz: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    func utcDate(_ string: String) -> Date {
        try! Date(string, strategy: .iso8601)
    }

    @Test func formatsAndParses() {
        let d = LocalDate(year: 2026, month: 3, day: 7)
        #expect(d.string == "2026-03-07")
        #expect(LocalDate(string: "2026-03-07") == d)
    }

    @Test(arguments: ["2026-02-30", "2026-1-01", "26-01-01", "2026-13-01", "2026-01-00", "", "abcd-ef-gh"])
    func rejectsInvalidStrings(_ raw: String) {
        #expect(LocalDate(string: raw) == nil)
    }

    @Test func acceptsLeapDay() {
        #expect(LocalDate(string: "2028-02-29") != nil)
        #expect(LocalDate(string: "2027-02-29") == nil)
    }

    @Test func usesLocalDayNotUTC() {
        // 21:30 UTC on Oct 13 is already 00:30 on Oct 14 in Istanbul (UTC+3).
        let instant = utcDate("2026-10-13T21:30:00Z")
        #expect(LocalDate(instant, calendar: calendar(istanbul)).string == "2026-10-14")
        #expect(LocalDate(instant, calendar: calendar(newYork)).string == "2026-10-13")
    }

    @Test func clockCrossesMidnight() {
        let before = AppClock.fixed(utcDate("2026-10-13T20:59:59Z"), timeZone: istanbul)
        let after = AppClock.fixed(utcDate("2026-10-13T21:00:00Z"), timeZone: istanbul)
        #expect(before.today.string == "2026-10-13")
        #expect(after.today.string == "2026-10-14")
        #expect(after.today.days(since: before.today) == 1)
    }

    @Test func handlesDSTSpringForward() {
        // New York skips 02:00–03:00 on 2026-03-08; the day is 23 hours long.
        let cal = calendar(newYork)
        let day = LocalDate(year: 2026, month: 3, day: 8)
        let start = day.startDate(in: cal)
        let next = day.adding(days: 1).startDate(in: cal)
        #expect(start == utcDate("2026-03-08T05:00:00Z"))
        #expect(next.timeIntervalSince(start) == 23 * 3600)
        // 00:30 EDT on Mar 9 is still Mar 9 locally.
        #expect(LocalDate(utcDate("2026-03-09T04:30:00Z"), calendar: cal).string == "2026-03-09")
    }

    @Test func handlesDSTFallBack() {
        // New York repeats 01:00–02:00 on 2026-11-01; the day is 25 hours long.
        let cal = calendar(newYork)
        let day = LocalDate(year: 2026, month: 11, day: 1)
        #expect(day.adding(days: 1).startDate(in: cal).timeIntervalSince(day.startDate(in: cal)) == 25 * 3600)
        #expect(LocalDate(utcDate("2026-11-02T04:59:00Z"), calendar: cal).string == "2026-11-01")
    }

    @Test func dayArithmetic() {
        let d = LocalDate(year: 2026, month: 12, day: 31)
        #expect(d.adding(days: 1).string == "2027-01-01")
        #expect(d.adding(days: -365).string == "2025-12-31")
        #expect(LocalDate(year: 2028, month: 2, day: 28).adding(days: 1).string == "2028-02-29")
        #expect(LocalDate(year: 2027, month: 1, day: 1).days(since: d) == 1)
        #expect(LocalDate.epoch.dayIndex == 0)
        #expect(LocalDate(year: 2025, month: 12, day: 31).dayIndex == -1)
        #expect(LocalDate(year: 2026, month: 10, day: 13).dayIndex == 285)
    }

    @Test func comparesChronologically() {
        #expect(LocalDate(year: 2026, month: 1, day: 31) < LocalDate(year: 2026, month: 2, day: 1))
        #expect(LocalDate(year: 2025, month: 12, day: 31) < LocalDate(year: 2026, month: 1, day: 1))
    }

    @Test func roundTripsThroughCodableAndDatabase() throws {
        let d = LocalDate(year: 2026, month: 10, day: 13)
        let json = try JSONEncoder().encode([d])
        #expect(String(decoding: json, as: UTF8.self) == "[\"2026-10-13\"]")
        #expect(try JSONDecoder().decode([LocalDate].self, from: json) == [d])

        let db = try DatabaseQueue()
        let fetched = try db.read { db in try LocalDate.fetchOne(db, sql: "SELECT ?", arguments: [d]) }
        #expect(fetched == d)
    }
}
