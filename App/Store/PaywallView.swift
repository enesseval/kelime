import KelimeCore
import KelimeUI
import RevenueCat
import SwiftUI

/// The Pro paywall: a night sky like onboarding, the reason it opened first, what Pro adds,
/// and the three plans (monthly, annual, lifetime) with the annual one chosen. Never shown on first launch.
struct PaywallView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let request: AppRouter.PaywallRequest

    enum Plan { case annual, monthly, lifetime }
    @State private var plan: Plan = .annual
    @State private var working = false
    @State private var toast: String?
    @State private var appeared = false

    private var purchases: PurchaseManager { app.purchases }

    struct Feature: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    /// What Pro adds. Everything else stays free.
    static let features = [
        Feature(id: "lists", symbol: "list.bullet.rectangle.portrait", title: "Sınırsız kendi listen", detail: "İstediğin kadar liste, hepsi widget'ta"),
        Feature(id: "share", symbol: "square.and.arrow.up", title: "Listeni paylaş", detail: "Arkadaşına ya da öğrencine gönder"),
        Feature(id: "exam", symbol: "calendar.badge.clock", title: "Sınav planı", detail: "Sınav gününe göre günlük kelime hedefi"),
        Feature(id: "rotation", symbol: "bolt.fill", title: "Daha sık yeni kelime", detail: "Widget'ta günde 24'e kadar kelime"),
        Feature(id: "puzzle", symbol: "puzzlepiece.extension", title: "Sana özel bulmaca", detail: "Zorlandıklarınla; bulmaca arşivi de açılır"),
    ]

    /// The feature that brought the learner here, shown first and highlighted.
    private var focus: String? {
        switch request.trigger {
        case .lists: "lists"
        case .share: "share"
        case .examPlan: "exam"
        case .rotation: "rotation"
        case .personalPuzzle, .archive: "puzzle"
        case .base: nil
        }
    }

    private var orderedFeatures: [Feature] {
        guard let focus else { return Self.features }
        return Self.features.filter { $0.id == focus } + Self.features.filter { $0.id != focus }
    }

    var body: some View {
        ZStack {
            OnboardingSky(hour: 21.5)
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Array(orderedFeatures.enumerated()), id: \.element.id) { index, feature in
                            featureTile(feature, highlighted: feature.id == focus)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.06 * Double(index)), value: appeared)
                        }
                    }
                    VStack(spacing: 10) {
                        planCard(.monthly, title: "Aylık", price: purchases.monthly?.storeProduct.localizedPriceString, note: "Her ay yenilenir, istediğin zaman iptal et", badge: nil)
                        planCard(.annual, title: "Yıllık", price: purchases.annual?.storeProduct.localizedPriceString, note: annualNote,
                                 badge: purchases.annualSaving.map { "%\($0) tasarruf" } ?? "En avantajlı")
                        planCard(.lifetime, title: "Ömür boyu", price: purchases.lifetime?.storeProduct.localizedPriceString, note: "Tek seferlik ödeme, abonelik yok", badge: nil)
                    }
                    if purchases.packages.isEmpty && !purchases.loadingProducts {
                        Button("Fiyatlar yüklenemedi · Tekrar dene") { Task { await purchases.loadProducts() } }
                            .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(Palette.accent)
                            .frame(minHeight: 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Kapat")
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .toast($toast)
        .task {
            appeared = true
            await purchases.loadProducts()
        }
        .onChange(of: purchases.isPro) { _, pro in
            if pro { dismiss() }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.accent.opacity(0.65), .clear], center: .center, startRadius: 4, endRadius: 70))
                    .frame(width: 110, height: 110)
                    .scaleEffect(appeared ? 1 : 0.6)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, isActive: appeared)
            }
            .frame(height: 64)
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: appeared)
            Text("KELİME WIDGET PRO")
                .font(KelimeFont.ui(12, weight: .bold, relativeTo: .caption))
                .tracking(1.4)
                .foregroundStyle(Palette.accent)
            Text(request.trigger.headline(deck: request.deck))
                .font(KelimeFont.english(34, relativeTo: .largeTitle))
                .tracking(-0.8)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// A compact feature: icon and title; the highlighted one (the reason the paywall opened)
    /// also says what it does.
    private func featureTile(_ feature: Feature, highlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: feature.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlighted ? Palette.onAccent : Palette.accent)
                .frame(width: 30, height: 30)
                .background(highlighted ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.accent.opacity(0.18)), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(feature.title)
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(highlighted ? Palette.accent.opacity(0.8) : .white.opacity(0.08)))
        .accessibilityElement(children: .combine)
        .accessibilityHint(feature.detail)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                Task { await buy() }
            } label: {
                if working { ProgressView().tint(Palette.onAccent) } else { Text(ctaTitle) }
            }
            .buttonStyle(PrimaryButtonStyle(height: 56))
            .disabled(working || selectedPackage == nil)
            .opacity(selectedPackage == nil ? 0.6 : 1)
            Text(plan == .lifetime ? "Bir kez öde, hep senin. Reklam yok, hesap gerekmez." : "Abonelik, dönem bitmeden en az 24 saat önce iptal edilmezse yenilenir. Ayarlar › Apple Kimliği › Abonelikler'den yönetilir.")
                .font(KelimeFont.ui(11, relativeTo: .caption2))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Geri yükle") { Task { await restore() } }
                Button("Koşullar") { openURL(Legal.termsURL) }
                Button("Gizlilik") { openURL(Legal.privacyURL) }
            }
            .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(.white.opacity(0.7))
            .frame(minHeight: 30)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.85), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var subtitle: String {
        switch request.trigger {
        case .lists: "Ücretsizde bir listen var. Pro ile istediğin kadar liste oluştur."
        case .share: "Listeni gönder; açan herkes kendi widget'ına ekler."
        case .rotation: "Kilit ekranında gün boyu daha çok kelime."
        case .personalPuzzle: "Zorlandığın ve öğrendiğin kelimelerden karışık bir bulmaca."
        case .archive: "Kaçırdığın günlerin bulmacalarını çöz."
        case .examPlan: "Sınav gününe kadar her gün kaç kelime çalışman gerektiğini görelim."
        case .base: "Kurs, sınav listeleri ve Hızlı Tekrar ücretsiz kalır; Pro yenilerini ekler."
        }
    }

    private var selectedPackage: Package? {
        switch plan {
        case .annual: purchases.annual
        case .monthly: purchases.monthly
        case .lifetime: purchases.lifetime
        }
    }

    /// "7 gün ücretsiz, sonra yıllık · ayda …".
    private var annualNote: String {
        let perMonth = purchases.annual?.storeProduct.localizedPricePerMonth.map { "ayda \($0)" }
        let lead = purchases.trialEligible ? "7 gün ücretsiz, sonra yıllık" : "Yıllık yenilenir"
        return [lead, perMonth].compactMap { $0 }.joined(separator: " · ")
    }

    private var ctaTitle: String {
        switch plan {
        case .annual: purchases.trialEligible ? "7 gün ücretsiz dene" : "Yıllık başla"
        case .monthly: "Aylık başla"
        case .lifetime: "Ömür boyu al"
        }
    }

    private func planCard(_ value: Plan, title: String, price: String?, note: String, badge: String?) -> some View {
        let selected = plan == value
        return Button {
            withAnimation(.snappy) { plan = value }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Palette.accent : .white.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                        if let badge {
                            Text(badge)
                                .font(KelimeFont.ui(11, weight: .bold))
                                .foregroundStyle(Palette.onAccent)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .background(Palette.green, in: Capsule())
                        }
                    }
                    Text(note).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 8)
                if let price {
                    Text(price).font(KelimeFont.ui(18, weight: .bold, relativeTo: .title3))
                } else if purchases.loadingProducts {
                    ProgressView().tint(.white)
                } else {
                    Text("—").font(KelimeFont.ui(18, weight: .bold, relativeTo: .title3)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(selected ? AnyShapeStyle(Palette.accent.opacity(0.18)) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Palette.accent : .white.opacity(0.1), lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func buy() async {
        guard let package = selectedPackage else { return }
        working = true
        defer { working = false }
        switch await purchases.purchase(package) {
        case .purchased:
            UsageCounter.count(.purchase)
            dismiss()
        case .pending: toast = "Satın alma onay bekliyor"
        case .cancelled: if let error = purchases.lastError { toast = error }
        }
    }

    private func restore() async {
        working = true
        defer { working = false }
        let restored = await purchases.restore()
        toast = restored ? "Pro geri yüklendi" : (purchases.lastError ?? "Geri yüklenecek satın alma bulunamadı")
    }
}

/// Legal links. Placeholders until the real pages exist.
enum Legal {
    /// Where feedback and error reports go (a prefilled email; GitHub issues when nil).
    static let supportEmail: String? = "enesseval@outlook.com"

    /// "Öneri gönder" in Ayarlar.
    static var feedbackURL: URL { report(subject: "Öneri", body: "") }

    /// "Hata bildir" on a word: the word and its card id are filled in.
    static func errorReportURL(for card: Card) -> URL {
        report(subject: "Hata: \(card.word)", body: """
            Kelime: \(card.word) (\(card.id))
            Anlam: \(card.meaning)
            Örnek: \(card.exampleEN)

            Hata ne?
            """)
    }

    private static func report(subject: String, body: String) -> URL {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let body = body + "\n\n— Kelime Widget \(version) (\(build))"
        var components: URLComponents
        if let supportEmail {
            components = URLComponents(string: "mailto:\(supportEmail)")!
            components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        } else {
            components = URLComponents(string: "https://github.com/enesseval/kelime/issues/new")!
            components.queryItems = [URLQueryItem(name: "title", value: subject), URLQueryItem(name: "body", value: body)]
        }
        return components.url!
    }
    static let termsURL = URL(string: "https://enesseval.github.io/kelime/kosullar.html")!
    static let privacyURL = URL(string: "https://enesseval.github.io/kelime/gizlilik.html")!
}
