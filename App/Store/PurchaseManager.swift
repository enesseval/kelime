import Foundation
import KelimeCore
import Observation
import RevenueCat

/// Pro through RevenueCat: the "kelime_widget_pro" entitlement, bought with one of the packages of the
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
    static let entitlement = "kelime_widget_pro"

    enum PurchaseResult {
        /// `kind` is trial when the purchase started a free trial of the plan, else paid.
        case purchased(kind: PurchaseKind, product: String)
        case pending, cancelled
    }

    /// The current offering's packages: monthly, annual, lifetime.
    private(set) var packages: [Package] = []
    /// Pro = bought or on the free 3-day trial (or the developer switch). Stored so views update.
    private(set) var isPro = false
    /// Bought: the entitlement or one of our products, without the trial.
    private(set) var isPurchased = false
    /// The free trial as last read; the state itself lives in the Keychain.
    private(set) var trial = TrialSnapshot(trial: nil, now: .now)
    private let trialManager = ReverseTrialManager(store: KeychainTrialStore())
    private var trialExpiry: Task<Void, Never>?
    private(set) var trialEligible = true
    private(set) var loadingProducts = false
    private(set) var lastError: String?
    /// What RevenueCat last reported, for Geliştirici: active entitlements and products.
    private(set) var diagnostics = "Henüz okunmadı"

    private var updatesTask: Task<Void, Never>?
    private weak var app: AppModel?

    /// "Deneme: N gün kaldı" while the free trial runs and nothing is bought.
    var trialDaysLeft: Int? { !isPurchased && trial.isActive ? trial.daysLeft : nil }

    /// The end-of-trial summary is due: over, not shown yet, nothing bought.
    var trialSummaryDue: Bool { !isPurchased && trial.summaryDue }

    func markTrialSummaryShown() {
        trialManager.markSummaryShown()
        trial = trialManager.refresh(now: .now)
    }

    /// Counts a use of a Pro feature for the end-of-trial summary (only while the trial runs).
    func noteTrialUse(_ feature: TrialFeature, key: String? = nil) {
        guard !isPurchased else { return }
        trialManager.note(feature, key: key, now: .now)
    }

    /// Reads the trial, starts it on the first launch ever, sends its signals once and plans a
    /// re-check for the moment it ends.
    private func updateTrial() {
        guard Self.isOnSale else { return }
        let snapshot = trialManager.refresh(now: .now)
        if snapshot.justStarted { Analytics.send(.trialStarted) }
        if snapshot.justEnded { Analytics.send(.trialEnded) }
        trial = snapshot
        trialExpiry?.cancel()
        if snapshot.isActive, let trial = snapshot.trial {
            let wait = trial.remaining(now: snapshot.now) + 0.5
            trialExpiry = Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                await self?.refreshEntitlement()
                await self?.app?.presentTrialSummaryIfDue()
            }
        }
    }

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
        // The last known purchase, so an offline first launch does not turn a buyer into a free
        // learner (or show them the end-of-trial summary).
        if let database = app.database, (try? database.reader.read { db in try ProEntitlement.isPurchasedCached(db: db) }) == true {
            isPurchased = Self.isOnSale
            isPro = Self.isOnSale
        }
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
        let eligibleBefore = trialEligible
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            await apply(result.customerInfo)
            let product = package.storeProduct.productIdentifier
            let onTrial = startedTrial(package: package, info: result.customerInfo, eligibleBefore: eligibleBefore)
            return .purchased(kind: onTrial ? .trial : .paid, product: product)
        } catch {
            let code = (error as NSError).code
            if code == ErrorCode.paymentPendingError.rawValue { return .pending }
            if code == ErrorCode.purchaseCancelledError.rawValue { return .cancelled }
            lastError = "Satın alma tamamlanamadı"
            return .cancelled
        }
    }

    /// Whether the purchase began a free trial of the plan. The entitlement's period type answers
    /// it; a product not attached to the entitlement falls back to the subscription's own period
    /// type, then to the product's free-trial introductory offer the learner was eligible for.
    private func startedTrial(package: Package, info: CustomerInfo, eligibleBefore: Bool) -> Bool {
        let product = package.storeProduct.productIdentifier
        if let entitlement = info.entitlements.all.values.first(where: { $0.productIdentifier == product }) {
            return entitlement.periodType == .trial
        }
        if let subscription = info.subscriptionsByProductIdentifier[product] { return subscription.periodType == .trial }
        return eligibleBefore && package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
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
        // No answer (offline) keeps what was known: a buyer is not turned into a free user.
        if let info = try? await Purchases.shared.customerInfo() { await apply(info) } else { await apply(nil, keepPurchase: true) }
    }

    /// Caches the entitlement and rebuilds the widgets when what they see changes. The cache holds
    /// the grant (`is_pro`: bought, or the developer switch), the last known purchase and the
    /// trial's end date; widgets and gates work out "bought or before the end" themselves.
    private func apply(_ info: CustomerInfo?, keepPurchase: Bool = false) async {
        // The entitlement, or any of our products owned directly: a product not attached to the
        // entitlement in RevenueCat must not leave a paying learner on the free plan.
        let entitled = info?.entitlements[Self.entitlement]?.isActive ?? false
        let products = (info?.activeSubscriptions ?? []).union(info?.nonSubscriptions.map(\.productIdentifier) ?? [])
        // No answer keeps what was last known (kept across launches in the database).
        let active = keepPurchase ? isPurchased : (entitled || ProEntitlement.isPro(activeProductIDs: products))
        if let info {
            let entitlements = info.entitlements.active.keys.sorted().joined(separator: ", ")
            diagnostics = "Yetki: \(entitlements.isEmpty ? "yok" : entitlements) · Ürünler: \(products.isEmpty ? "yok" : products.sorted().joined(separator: ", "))"
        }
        updateTrial()
        isPurchased = Self.isOnSale && active
        // A buyer never sees the end-of-trial summary.
        if isPurchased, trial.summaryDue { trialManager.markSummaryShown() }
        let grant = Self.isOnSale && (active || DevTools.forcePro)
        isPro = grant || (Self.isOnSale && trial.isActive)
        guard let app, let database = app.database else { return }
        let onSale = Self.isOnSale
        let purchased = isPurchased, trialEnd = onSale ? trial.trial?.endsAt : nil
        let canWriteTrial = trial.trial != nil || !onSale
        // Compared with the state last acted on (kept in the database), not with the state the
        // database implies: a trial that ran out while the app was closed changed nothing there.
        let changed = (try? await database.writer.write { db -> Bool in
            try ProEntitlement.cache(grant, db: db)
            if info != nil || !onSale { try ProEntitlement.cachePurchased(purchased, db: db) }
            if canWriteTrial { try ProEntitlement.cacheTrialEnd(trialEnd, db: db) }
            return try ProEntitlement.noteEffective(try ProEntitlement.isPro(db: db), db: db)
        }) ?? false
        if changed {
            await app.write(rebuildQueue: true) { _ in }
        }
    }

    /// Current plan label for Ayarlar.
    var planLabel: String {
        if let days = trialDaysLeft { return "Deneme: \(days) gün kaldı" }
        guard isPro else { return "Ücretsiz" }
        return DevTools.forcePro ? "Pro (geliştirici)" : "Pro"
    }
}
