import Foundation

/// When Pro is offered on its own ("moment"): after the learner has come back on a few days,
/// at most twice, never while Pro (or the free trial) is on, never right after another paywall.
public enum PaywallMomentRule {
    public static let studyDays = 3
    public static let maxOffers = 2
    public static let daysBetween: TimeInterval = 14 * 24 * 3600
    public static let quietAfterPaywall: TimeInterval = 48 * 3600

    /// `isPro` includes the free trial: no moment paywall appears while it runs.
    public static func shouldOffer(isPro: Bool, studyDays days: Int, offers: Int, lastOffer: Date?, lastPaywall: Date?, now: Date) -> Bool {
        guard !isPro, days >= studyDays, offers < maxOffers else { return false }
        if let lastOffer, now.timeIntervalSince(lastOffer) < daysBetween { return false }
        if let lastPaywall, now.timeIntervalSince(lastPaywall) < quietAfterPaywall { return false }
        return true
    }
}
