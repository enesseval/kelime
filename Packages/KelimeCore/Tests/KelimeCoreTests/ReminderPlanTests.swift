import Testing
@testable import KelimeCore

/// The daily reminder plan (docs/V1_1_PLAN.md §1): no reminder on a studied day, the streak text
/// when the streak is at risk.
struct ReminderPlanTests {
    let today = LocalDate(year: 2026, month: 11, day: 13)

    func streak(studied offsets: [Int]) -> StreakStatus {
        Streak.compute(days: Set(offsets.map { today.adding(days: -$0) }), today: today, freezesPerWeek: 1)
    }

    @Test func studiedTodaySkipsTodayAndWarnsTomorrow() {
        let items = ReminderPlan.items(streak: streak(studied: [0, 1, 2]), todayStillAhead: true)
        #expect(items.first?.offset == 1)
        #expect(items.first?.body == "3 günlük serin bu akşam bitiyor. 2 dakikalık bir tur yeter.")
        #expect(items.dropFirst().allSatisfy { $0.title == ReminderPlan.regularTitle })
        #expect(items.count == ReminderPlan.daysAhead - 1)
    }

    @Test func streakAtRiskChangesTodaysText() {
        let items = ReminderPlan.items(streak: streak(studied: [1, 2]), todayStillAhead: true)
        #expect(items[0].offset == 0)
        #expect(items[0].title == "Serin bu akşam bitiyor")
        #expect(items[0].body == "2 günlük serin bu akşam bitiyor. 2 dakikalık bir tur yeter.")
        #expect(items[1].title == ReminderPlan.regularTitle)
    }

    @Test func noStreakGetsTheRegularText() {
        let items = ReminderPlan.items(streak: streak(studied: []), todayStillAhead: true)
        #expect(items.allSatisfy { $0.body == ReminderPlan.regularBody })
        #expect(items.map(\.offset) == Array(0..<ReminderPlan.daysAhead))
    }

    @Test func passedTimeSkipsToday() {
        let items = ReminderPlan.items(streak: streak(studied: [1]), todayStillAhead: false)
        #expect(items.first?.offset == 1)
    }
}
