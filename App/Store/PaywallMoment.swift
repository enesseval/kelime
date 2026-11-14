import Foundation
import KelimeCore

/// Pro is offered on its own only after the learner has come back: studied on a few different
/// days, at the end of a good round, never right after onboarding. Locked features still open
/// the paywall when tapped; this is the one unprompted offer.
enum PaywallMoment {
    private static let countKey = "paywallMoment.count"
    private static let lastKey = "paywallMoment.last"
    private static let lastPaywallKey = "paywall.lastShown"

    /// The rule itself lives in KelimeCore (`PaywallMomentRule`): never while Pro or on the trial.
    static func shouldOffer(isPro: Bool, studyDays days: Int, now: Date = .now) -> Bool {
        let defaults = UserDefaults.standard
        return PaywallMomentRule.shouldOffer(
            isPro: isPro, studyDays: days, offers: defaults.integer(forKey: countKey),
            lastOffer: defaults.object(forKey: lastKey) as? Date,
            lastPaywall: defaults.object(forKey: lastPaywallKey) as? Date, now: now)
    }

    /// Called for every paywall; the offer's own count only moves for `.moment`.
    static func noteShown(_ trigger: PaywallTrigger, now: Date = .now) {
        let defaults = UserDefaults.standard
        if trigger == .moment {
            defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
            defaults.set(now, forKey: lastKey)
        }
        defaults.set(now, forKey: lastPaywallKey)
    }
}
