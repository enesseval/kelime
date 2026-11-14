import Foundation
import Testing
@testable import KelimeCore

struct UsageSignalTests {
    @Test func everyPaywallTriggerSendsItsOwnNameAsSource() {
        let expected = ["moment", "archive", "personalPuzzle", "examPlan", "lists", "share", "discover", "rotation", "base", "trialEnded"]
        #expect(Set(PaywallTrigger.allCases.map(\.rawValue)) == Set(expected))
        for trigger in PaywallTrigger.allCases {
            let signal = UsageSignal.paywallShown(trigger)
            #expect(signal.name == "Usage.paywallShown")
            #expect(signal.parameters == ["source": trigger.rawValue])
        }
    }

    @Test func purchaseSignalCarriesKindAndProduct() {
        let trial = UsageSignal.purchase(kind: .trial, product: ProEntitlement.yearlyID)
        #expect(trial.name == "Usage.purchase")
        #expect(trial.parameters == ["kind": "trial", "product": "pro.yearly"])
        #expect(UsageSignal.purchase(kind: .paid, product: ProEntitlement.lifetimeID).parameters == ["kind": "paid", "product": "pro.lifetime"])
        #expect(UsageSignal.trialStarted == UsageSignal("trial.started"))
        #expect(UsageSignal.trialEnded == UsageSignal("trial.ended"))
    }
}
