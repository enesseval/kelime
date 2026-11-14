import Foundation

/// How a purchase started: the free trial of a plan, or a paid purchase.
public enum PurchaseKind: String, Sendable, CaseIterable {
    case trial
    case paid
}

/// A usage signal as it goes to the analytics service: name and parameters. The rules live
/// here so both the values and the names can be tested and match the Android app exactly.
public struct UsageSignal: Equatable, Sendable {
    public var name: String
    public var parameters: [String: String]

    public init(_ name: String, _ parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
    }

    /// The paywall opened; `source` is the trigger's name (`moment`, `archive`, ...).
    public static func paywallShown(_ trigger: PaywallTrigger) -> UsageSignal {
        UsageSignal("Usage.paywallShown", ["source": trigger.rawValue])
    }

    /// A purchase went through; `product` is the store product id.
    public static func purchase(kind: PurchaseKind, product: String) -> UsageSignal {
        UsageSignal("Usage.purchase", ["kind": kind.rawValue, "product": product])
    }

    /// The free trial began (first launch).
    public static let trialStarted = UsageSignal("trial.started")
    /// The free trial ran out (sent once).
    public static let trialEnded = UsageSignal("trial.ended")
}
