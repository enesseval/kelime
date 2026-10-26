import Foundation
import KelimeCore
import Observation
import RevenueCat

/// Pro through RevenueCat: the "pro" entitlement, bought with one of the packages of the
/// current offering (monthly, annual with a 7-day trial, lifetime). The entitlement is cached
/// in the shared database for the widget and the gates.
@MainActor
@Observable
final class PurchaseManager {
    /// Pro is sold: own lists beyond the first, sharing, the exam plan, faster widget changes and
    /// the personal puzzle with the archive. Off makes nobody Pro and hides the paywall and the
    /// PRO section, with the purchase code kept.
    static let isOnSale = true
    static let apiKey = "appl_JjGFzNpxOuvScWuVgPqyPEzDTeR"
    static let entitlement = "pro"

    enum PurchaseResult {
        case purchased, pending, cancelled
    }

    /// The current offering's packages: monthly, annual, lifetime.
    private(set) var packages: [Package] = []
    private(set) var isPro = false
    private(set) var trialEligible = true
    private(set) var loadingProducts = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private weak var app: AppModel?

    var monthly: Package? { packages.first { $0.packageType == .monthly } }
    var annual: Package? { packages.first { $0.packageType == .annual } }
    var lifetime: Package? { packages.first { $0.packageType == .lifetime } }

    /// How much cheaper a year is than twelve months, in percent, when both exist.
    var annualSaving: Int? {
        guard let monthly, let annual else { return nil }
        let twelve = monthly.storeProduct.priceDecimalNumber.doubleValue * 12
        guard twelve > 0 else { return nil }
        let saving = Int(((1 - annual.storeProduct.priceDecimalNumber.doubleValue / twelve) * 100).rounded(.down))
        return saving > 0 ? saving : nil
    }

    /// Configures RevenueCat and listens for entitlement changes. Call once at launch.
    func start(app: AppModel) {
        self.app = app
        guard Self.isOnSale else {
            Task { await apply(nil) }
            return
        }
        guard updatesTask == nil else { return }
        if !Purchases.isConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: Self.apiKey)
        }
        updatesTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                await self?.apply(info)
            }
        }
        Task { await loadProducts() }
    }

    func loadProducts() async {
        guard Self.isOnSale, packages.isEmpty, !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let order: [PackageType] = [.monthly, .annual, .lifetime]
            let available = try await Purchases.shared.offerings().current?.availablePackages ?? []
            packages = available.sorted { (order.firstIndex(of: $0.packageType) ?? 9) < (order.firstIndex(of: $1.packageType) ?? 9) }
            if packages.isEmpty { lastError = "Ürünler yüklenemedi" }
            if let annual {
                let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: annual.storeProduct)
                trialEligible = status != .ineligible
            }
        } catch {
            lastError = "Ürünler yüklenemedi"
        }
    }

    func purchase(_ package: Package) async -> PurchaseResult {
        lastError = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            await apply(result.customerInfo)
            return .purchased
        } catch {
            let code = (error as NSError).code
            if code == ErrorCode.paymentPendingError.rawValue { return .pending }
            if code == ErrorCode.purchaseCancelledError.rawValue { return .cancelled }
            lastError = "Satın alma tamamlanamadı"
            return .cancelled
        }
    }

    /// "Satın alımları geri yükle".
    func restore() async -> Bool {
        lastError = nil
        do {
            await apply(try await Purchases.shared.restorePurchases())
        } catch {
            lastError = "Geri yükleme tamamlanamadı"
        }
        return isPro
    }

    /// Reads the entitlement again (e.g. after the developer Pro switch).
    func refreshEntitlement() async {
        guard Self.isOnSale else { return await apply(nil) }
        await apply(try? await Purchases.shared.customerInfo())
    }

    /// Caches the entitlement and rebuilds the widgets when it changes.
    private func apply(_ info: CustomerInfo?) async {
        let active = info?.entitlements[Self.entitlement]?.isActive ?? false
        let pro = Self.isOnSale && (active || DevTools.forcePro)
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
        return DevTools.forcePro ? "Pro (geliştirici)" : "Pro"
    }
}
