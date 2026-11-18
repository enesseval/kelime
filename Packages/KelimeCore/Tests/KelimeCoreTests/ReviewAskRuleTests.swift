import Foundation
import Testing
@testable import KelimeCore

struct ReviewAskRuleTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func ask(days: Int = 3, accuracy: Double = 0.9, paywall: Bool = false, asks: Int = 0,
             lastAsk: Date? = nil, tapped: Bool = false) -> Bool {
        ReviewAskRule.shouldAsk(studyDays: days, accuracy: accuracy, paywallThisSession: paywall,
                                asks: asks, lastAsk: lastAsk, tappedRateRow: tapped, now: now)
    }
    func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 24 * 3600) }

    @Test func needsThirdStudyDay() {
        #expect(!ask(days: 2))
        #expect(ask(days: 3))
    }
    @Test func needsEightyPercent() {
        #expect(ask(accuracy: 0.8))
        #expect(!ask(accuracy: 0.79))
    }
    @Test func notAfterPaywallInSession() { #expect(!ask(paywall: true)) }
    @Test func hundredTwentyDaysApart() {
        #expect(!ask(asks: 1, lastAsk: ago(119)))
        #expect(ask(asks: 1, lastAsk: ago(120)))
    }
    @Test func atMostThree() { #expect(!ask(asks: 3, lastAsk: ago(400))) }
    @Test func neverAfterRateRowTap() { #expect(!ask(tapped: true)) }
}
