import Foundation
import GRDB

/// Product ids and the Pro entitlement cache.
///
/// RevenueCat lives in the app (entitlement "pro"); the result is cached in the shared database (`is_pro`) so the
/// widget, the scheduler and every gate read one value.
public enum ProEntitlement {
    public static let lifetimeID = "pro.lifetime"
    public static let yearlyID = "pro.yearly"
    public static let monthlyID = "pro.monthly"
    public static let allProductIDs = [lifetimeID, yearlyID, monthlyID]

    /// Pro when any active transaction is one of ours.
    public static func isPro(activeProductIDs: some Sequence<String>) -> Bool {
        activeProductIDs.contains { allProductIDs.contains($0) }
    }

    /// Whether Pro is open at `now`: the stored grant (bought, or the developer switch) or a free
    /// trial that has not ended. Widgets and gates read this, so a trial that ends while the app
    /// stays closed still ends.
    public static func isPro(db: Database, now: Date = .now) throws -> Bool {
        if try Settings.bool(.isPro, in: db) { return true }
        return isTrialOpen(try Settings.int(.trialEnd, in: db), now: now)
    }

    public static func isTrialOpen(_ trialEnd: Int?, now: Date) -> Bool {
        guard let trialEnd else { return false }
        return now.timeIntervalSince1970 < Double(trialEnd)
    }

    /// The last known purchase, kept for the next launch.
    public static func isPurchasedCached(db: Database) throws -> Bool { try Settings.bool(.isPurchased, in: db) }

    public static func cachePurchased(_ purchased: Bool, db: Database) throws {
        guard try Settings.bool(.isPurchased, in: db) != purchased || (try Settings.string(.isPurchased, in: db)) == nil else { return }
        try Settings.set(.isPurchased, purchased, in: db)
    }

    /// Stores when the trial ends (nil: no trial). Returns true when it changed.
    @discardableResult
    public static func cacheTrialEnd(_ date: Date?, db: Database) throws -> Bool {
        let new = date.map { Int($0.timeIntervalSince1970) }
        guard try Settings.int(.trialEnd, in: db) != new else { return false }
        try Settings.set(.trialEnd, new, in: db)
        return true
    }

    /// Stores the entitlement (`is_pro` is the grant: bought or the developer switch). Returns true when it changed, so callers can rebuild the widget
    /// queue (Pro unlocks decks and faster rotation).
    @discardableResult
    public static func cache(_ isPro: Bool, db: Database) throws -> Bool {
        let old = try Settings.bool(.isPro, in: db)
        guard old != isPro else { return false }
        try Settings.set(.isPro, isPro, in: db)
        return true
    }
}
