import Foundation

/// When the system rating prompt may be requested on its own (docs/SYNC.md 2026-11-18
/// "Uygulamayı değerlendir"): at the end of a good round, from the 3rd study day on, never in a
/// session that already showed a paywall, at most 3 times and 120 days apart, and never once the
/// learner tapped "Uygulamayı değerlendir".
public enum ReviewAskRule {
    public static let studyDays = 3
    public static let minAccuracy = 0.8
    public static let maxAsks = 3
    public static let daysBetween: TimeInterval = 120 * 24 * 3600

    public static func shouldAsk(
        studyDays days: Int, accuracy: Double, paywallThisSession: Bool,
        asks: Int, lastAsk: Date?, tappedRateRow: Bool, now: Date
    ) -> Bool {
        guard days >= studyDays, accuracy >= minAccuracy, !paywallThisSession,
              asks < maxAsks, !tappedRateRow else { return false }
        if let lastAsk, now.timeIntervalSince(lastAsk) < daysBetween { return false }
        return true
    }
}
