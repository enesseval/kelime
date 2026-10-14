import Foundation
import GRDB

/// Product ids and the Pro entitlement cache.
///
/// StoreKit lives in the app; the result is cached in the shared database (`is_pro`) so the
/// widget, the scheduler and every gate read one value.
public enum ProEntitlement {
    public static let lifetimeID = "pro.lifetime"
    public static let yearlyID = "pro.yearly"
    public static let allProductIDs = [lifetimeID, yearlyID]

    /// Pro when any active transaction is one of ours.
    public static func isPro(activeProductIDs: some Sequence<String>) -> Bool {
        activeProductIDs.contains { allProductIDs.contains($0) }
    }

    /// Stores the entitlement. Returns true when it changed, so callers can rebuild the widget
    /// queue (Pro unlocks decks and faster rotation).
    @discardableResult
    public static func cache(_ isPro: Bool, db: Database) throws -> Bool {
        let old = try Settings.bool(.isPro, in: db)
        guard old != isPro else { return false }
        try Settings.set(.isPro, isPro, in: db)
        return true
    }
}
