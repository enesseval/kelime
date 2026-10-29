import Foundation
import StoreKit
import SwiftUI

/// Asks for an App Store rating at good moments: a finished daily puzzle, or a Quick Review
/// with at least 8 right. Never in the first two days, and at most once every 60 days (iOS
/// also shows the system prompt at most three times a year).
enum ReviewPrompt {
    private static let firstSeenKey = "review.firstSeen"
    private static let lastAskedKey = "review.lastAsked"
    private static let goodMomentsKey = "review.goodMoments"

    /// Notes the first launch, so the two-day wait has a start.
    static func noteLaunch() {
        if UserDefaults.standard.object(forKey: firstSeenKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstSeenKey)
        }
    }

    /// Counts a good moment and says whether to ask now: the third good moment or later,
    /// two days after install, sixty days after the last ask.
    static func shouldAsk(now: Date = .now) -> Bool {
        let defaults = UserDefaults.standard
        let moments = defaults.integer(forKey: goodMomentsKey) + 1
        defaults.set(moments, forKey: goodMomentsKey)
        guard moments >= 3,
              let first = defaults.object(forKey: firstSeenKey) as? Date,
              now.timeIntervalSince(first) >= 2 * 86_400
        else { return false }
        if let last = defaults.object(forKey: lastAskedKey) as? Date, now.timeIntervalSince(last) < 60 * 86_400 {
            return false
        }
        defaults.set(now, forKey: lastAskedKey)
        return true
    }
}

extension View {
    /// Shows the system rating prompt a moment after this view appears, when `ReviewPrompt`
    /// says it is a good time and `isGoodMoment` holds.
    func askForReview(when isGoodMoment: Bool) -> some View {
        modifier(ReviewPromptModifier(isGoodMoment: isGoodMoment))
    }
}

private struct ReviewPromptModifier: ViewModifier {
    let isGoodMoment: Bool
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.task {
            guard isGoodMoment, ReviewPrompt.shouldAsk() else { return }
            try? await Task.sleep(for: .seconds(1.2))
            requestReview()
        }
    }
}
