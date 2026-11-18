import Foundation
import KelimeCore

/// The app's side of `ReviewAskRule`: counts and dates in UserDefaults, plus the store links.
enum ReviewAsk {
    private static let countKey = "reviewAsk.count"
    private static let lastKey = "reviewAsk.last"
    private static let tappedKey = "reviewAsk.tapped"
    /// A paywall or trial summary showed in this launch.
    nonisolated(unsafe) static var paywallThisSession = false

    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6823302964?action=write-review")!
    static let storeURL = URL(string: "https://apps.apple.com/tr/app/id6823302964")!
    static let shareText = "Kilit ekranında her gün İngilizce kelime öğreniyorum: Kilit Kelime. Ücretsiz indir: \(storeURL.absoluteString)"

    static func shouldAsk(studyDays: Int, accuracy: Double, now: Date = .now) -> Bool {
        let d = UserDefaults.standard
        return ReviewAskRule.shouldAsk(
            studyDays: studyDays, accuracy: accuracy, paywallThisSession: paywallThisSession,
            asks: d.integer(forKey: countKey), lastAsk: d.object(forKey: lastKey) as? Date,
            tappedRateRow: d.bool(forKey: tappedKey), now: now)
    }

    static func noteAsked(now: Date = .now) {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: countKey) + 1, forKey: countKey)
        d.set(now, forKey: lastKey)
    }

    static func noteRateRowTapped() { UserDefaults.standard.set(true, forKey: tappedKey) }
}
