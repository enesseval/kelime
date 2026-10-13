import Foundation
import Testing
@testable import KelimeCore

struct WidgetSchedulerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!

    func calendar(_ tz: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    func date(_ s: String) -> Date { try! Date(s, strategy: .iso8601) }

    @Test func weights() {
        let day: TimeInterval = 24 * 3600
        #expect(WidgetScheduler.weight(.init(cardID: "a", state: .struggling), now: now) == 3)
        #expect(WidgetScheduler.weight(.init(cardID: "a", state: .new), now: now) == 1)
        #expect(WidgetScheduler.weight(.init(cardID: "a", state: .learned, lastShownAt: now - 15 * day), now: now) == 0.2)
        #expect(WidgetScheduler.weight(.init(cardID: "a", state: .learned, lastShownAt: now - 13 * day), now: now) == 0)
        #expect(WidgetScheduler.weight(.init(cardID: "a", state: .learned), now: now) == 0.2)
    }

    @Test func neverRepeatsWithinTwentySlots() {
        var rng = SeededGenerator(seed: 1)
        let pool = (0..<25).map { SchedulerCandidate(cardID: "c\($0)", state: $0 < 5 ? .struggling : .new) }
        var history: [String] = []
        for _ in 0..<2000 {
            let id = WidgetScheduler.pick(from: pool, recent: history.reversed(), now: now, using: &rng)!
            #expect(!history.suffix(20).contains(id))
            history.append(id)
        }
    }

    @Test func strugglingIsPickedAboutThreeTimesAsOften() {
        var rng = SeededGenerator(seed: 42)
        let pool = [SchedulerCandidate(cardID: "s", state: .struggling), SchedulerCandidate(cardID: "n", state: .new)]
        var counts: [String: Int] = [:]
        for _ in 0..<20_000 {
            counts[WidgetScheduler.pick(from: pool, recent: [], now: now, using: &rng)!, default: 0] += 1
        }
        let ratio = Double(counts["s"]!) / Double(counts["n"]!)
        #expect((2.8...3.2).contains(ratio))
    }

    @Test func recentlyShownLearnedCardsAreSkipped() {
        var rng = SeededGenerator(seed: 3)
        let pool = [
            SchedulerCandidate(cardID: "fresh", state: .learned, lastShownAt: now - 3600),
            SchedulerCandidate(cardID: "old", state: .learned, lastShownAt: now - 30 * 24 * 3600),
        ]
        for _ in 0..<200 {
            #expect(WidgetScheduler.pick(from: pool, recent: [], now: now, using: &rng) == "old")
        }
    }

    @Test func tinyPoolReusesTheOldestRecentCard() {
        var rng = SeededGenerator(seed: 4)
        let pool = ["a", "b", "c"].map { SchedulerCandidate(cardID: $0, state: .new) }
        // Newest first: "b" was shown longest ago.
        #expect(WidgetScheduler.pick(from: pool, recent: ["a", "c", "b"], now: now, using: &rng) == "b")
    }

    @Test func nothingWeightedReturnsNil() {
        var rng = SeededGenerator(seed: 5)
        let pool = [SchedulerCandidate(cardID: "a", state: .learned, lastShownAt: now)]
        #expect(WidgetScheduler.pick(from: pool, recent: [], now: now, using: &rng) == nil)
        #expect(WidgetScheduler.pick(from: [], recent: [], now: now, using: &rng) == nil)
    }

    @Test func slotsAlignToLocalDayStart() {
        let cal = calendar(istanbul)
        let at = date("2026-10-13T07:20:00Z") // 10:20 in Istanbul
        #expect(WidgetScheduler.slotStart(containing: at, interval: .threeHours, calendar: cal) == date("2026-10-13T06:00:00Z"))
        #expect(WidgetScheduler.slotStart(containing: at, interval: .thirtyMinutes, calendar: cal) == date("2026-10-13T07:00:00Z"))
        #expect(WidgetScheduler.slotStart(containing: at, interval: .daily, calendar: cal) == date("2026-10-12T21:00:00Z"))
    }

    @Test func slotsCoverTheNext24Hours() {
        let cal = calendar(istanbul)
        let at = date("2026-10-13T07:20:00Z")
        let threeHourly = WidgetScheduler.slots(from: at, interval: .threeHours, calendar: cal)
        #expect(threeHourly.count == 9) // 09:00 … 09:00 next day
        #expect(threeHourly.first == date("2026-10-13T06:00:00Z"))
        #expect(WidgetScheduler.slots(from: at, interval: .thirtyMinutes, calendar: cal).count == 49)
        #expect(WidgetScheduler.slots(from: at, interval: .daily, calendar: cal).count == 2)
        #expect(zip(threeHourly, threeHourly.dropFirst()).allSatisfy { $1.timeIntervalSince($0) == 3 * 3600 })
    }

    @Test func slotsRestartAtMidnightOnDSTDays() {
        // New York's 2026-03-08 is 23 hours long; the next day's slots still start at midnight.
        let cal = calendar(TimeZone(identifier: "America/New_York")!)
        let at = date("2026-03-08T15:00:00Z") // 11:00 EDT
        let slots = WidgetScheduler.slots(from: at, interval: .threeHours, calendar: cal)
        let nextMidnight = cal.startOfDay(for: date("2026-03-09T12:00:00Z"))
        #expect(slots.contains(nextMidnight))
        #expect(slots == slots.sorted())
        #expect(Set(slots).count == slots.count)
        let daily = WidgetScheduler.slots(from: at, interval: .daily, calendar: cal)
        #expect(daily == [cal.startOfDay(for: at), nextMidnight])
    }

    @Test func proIntervalsFallBackForFreeUsers() {
        #expect(RotationInterval.thirtyMinutes.effective(isPro: false) == .threeHours)
        #expect(RotationInterval.oneHour.effective(isPro: false) == .threeHours)
        #expect(RotationInterval.daily.effective(isPro: false) == .daily)
        #expect(RotationInterval.thirtyMinutes.effective(isPro: true) == .thirtyMinutes)
    }

    @Test func deckEntitlement() {
        #expect(DeckID.entitled(enabled: [.b1, .yds], isPro: false) == [.b1])
        #expect(DeckID.entitled(enabled: [.yds], isPro: false) == [.a2, .b1])
        #expect(DeckID.entitled(enabled: [], isPro: true) == [.a2, .b1])
        #expect(DeckID.entitled(enabled: [.c1, .yds], isPro: true) == [.c1, .yds])
    }
}
