import Foundation
import KelimeCore
import Observation
import StoreKit

/// StoreKit 2 purchases: one non-consumable (lifetime) and one yearly subscription with a
/// 7-day free trial. Entitlement comes from `Transaction.currentEntitlements` plus
/// `Transaction.updates`, and is cached in the shared database for the widget and the gates.
@MainActor
@Observable
final class PurchaseManager {
    enum PurchaseResult {
        case purchased, pending, cancelled
    }

    private(set) var products: [String: Product] = [:]
    private(set) var isPro = false
    private(set) var trialEligible = true
    private(set) var loadingProducts = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private weak var app: AppModel?

    var lifetime: Product? { products[ProEntitlement.lifetimeID] }
    var yearly: Product? { products[ProEntitlement.yearlyID] }

    /// Starts listening for transactions and refreshes the entitlement. Call once at launch.
    func start(app: AppModel) {
        self.app = app
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard products.isEmpty, !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProEntitlement.allProductIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            if loaded.isEmpty { lastError = "Ürünler yüklenemedi" }
            if let subscription = yearly?.subscription {
                trialEligible = await subscription.isEligibleForIntroOffer
            }
        } catch {
            lastError = "Ürünler yüklenemedi"
        }
    }

    func purchase(_ product: Product) async -> PurchaseResult {
        lastError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Satın alma doğrulanamadı"
                    return .cancelled
                }
                await transaction.finish()
                await refreshEntitlement()
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            lastError = "Satın alma tamamlanamadı"
            return .cancelled
        }
    }

    /// "Satın alımları geri yükle".
    func restore() async -> Bool {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Geri yükleme tamamlanamadı"
        }
        await refreshEntitlement()
        return isPro
    }

    /// Reads current entitlements and caches the result; rebuilds widgets when it changes.
    func refreshEntitlement() async {
        var active: [String] = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.revocationDate == nil {
                active.append(transaction.productID)
            }
        }
        let pro = ProEntitlement.isPro(activeProductIDs: active)
        isPro = pro
        guard let app, let database = app.database else { return }
        let changed = (try? await database.writer.write { db in try ProEntitlement.cache(pro, db: db) }) ?? false
        if changed {
            await app.write(rebuildQueue: true) { _ in }
        }
    }

    /// Current plan label for Ayarlar.
    var planLabel: String {
        guard isPro else { return "Ücretsiz" }
        return "Pro"
    }
}
