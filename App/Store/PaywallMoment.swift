import Foundation
import KelimeCore

/// Pro is offered on its own only after the learner has come back: studied on a few different
/// days, at the end of a good round, never right after onboarding. Locked features still open
/// the paywall when tapped; this is the one unprompted offer.
enum PaywallMoment {
    /// Different days with a finished round, solved crossword word or finished game.
    static let studyDays = 3
    /// At most this many offers, this far apart.
    static let maxOffers = 2
    static let daysBetween: TimeInterval = 14 * 24 * 3600
    /// No offer within this long after any paywall (a locked feature the learner tapped).
    static let quietAfterPaywall: TimeInterval = 48 * 3600

    private static let countKey = "paywallMoment.count"
    private static let lastKey = "paywallMoment.last"
    private static let lastPaywallKey = "paywall.lastShown"

    static func shouldOffer(studyDays days: Int, now: Date = .now) -> Bool {
        let defaults = UserDefaults.standard
        guard days >= studyDays, defaults.integer(forKey: countKey) < maxOffers else { return false }
        if let last = defaults.object(forKey: lastKey) as? Date, now.timeIntervalSince(last) < daysBetween { return false }
        if let last = defaults.object(forKey: lastPaywallKey) as? Date, now.timeIntervalSince(last) < quietAfterPaywall { return false }
        return true
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
