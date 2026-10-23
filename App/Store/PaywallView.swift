import KelimeCore
import KelimeUI
import StoreKit
import SwiftUI

/// Soft, contextual paywall. Never shown on first launch; the headline follows the trigger.
struct PaywallView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let request: AppRouter.PaywallRequest

    enum Plan { case lifetime, yearly }
    @State private var plan: Plan = .lifetime
    @State private var working = false
    @State private var toast: String?

    private var purchases: PurchaseManager { app.purchases }

    /// What Pro adds. Everything else stays free.
    static let benefits = [
        "Sınırsız kendi listen, widget'ta",
        "Listelerini paylaş",
        "Sınav planı: sınav gününe göre günlük hedef",
        "Widget'ta daha sık yeni kelime",
        "Sana özel bulmaca ve bulmaca arşivi",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Palette.surface2, in: Circle())
                }
                .accessibilityLabel("Kapat")
            }
            .padding(.trailing, -8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KELİME WIDGET PRO")
                            .font(KelimeFont.ui(12, weight: .bold, relativeTo: .caption))
                            .tracking(1.2)
                            .foregroundStyle(Palette.accent)
                        Text(request.trigger.headline(deck: request.deck))
                            .font(KelimeFont.english(44, relativeTo: .largeTitle))
                            .tracking(-0.9)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(KelimeFont.ui(15, relativeTo: .subheadline))
                            .foregroundStyle(Palette.ink2)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Self.benefits, id: \.self) { benefit in
                            HStack(spacing: 12) {
                                Text("✓")
                                    .font(KelimeFont.ui(12, weight: .bold))
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 22, height: 22)
                                    .background(Palette.accentSoft, in: Circle())
                                Text(benefit).font(KelimeFont.ui(16, relativeTo: .body))
                            }
                        }
                    }
                    VStack(spacing: 10) {
                        planCard(.lifetime, title: "Ömür boyu", price: purchases.lifetime?.displayPrice, note: "Tek seferlik ödeme, abonelik yok", recommended: true)
                        planCard(.yearly, title: "Yıllık", price: purchases.yearly?.displayPrice, note: purchases.trialEligible ? "7 gün ücretsiz dene" : "Yıllık yenilenir", recommended: false)
                    }
                    .padding(.top, 4)
                }
            }
            .scrollIndicators(.hidden)

            Button {
                Task { await buy() }
            } label: {
                if working { ProgressView().tint(Palette.onAccent) } else { Text(ctaTitle) }
            }
            .buttonStyle(PrimaryButtonStyle(height: 54))
            .disabled(working || selectedProduct == nil)
            .opacity(selectedProduct == nil ? 0.6 : 1)

            if purchases.products.isEmpty && !purchases.loadingProducts {
                Button("Fiyatlar yüklenemedi · Tekrar dene") { Task { await purchases.loadProducts() } }
                    .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            Text("Reklam yok. Hesap yok. İnternetsiz çalışır.")
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity)
            HStack(spacing: 18) {
                Button("Geri yükle") { Task { await restore() } }
                Button("Koşullar") { openURL(Legal.termsURL) }
                Button("Gizlilik") { openURL(Legal.privacyURL) }
            }
            .font(KelimeFont.ui(12, relativeTo: .caption))
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .screenBackground()
        .toast($toast)
        .task { await purchases.loadProducts() }
        .onChange(of: purchases.isPro) { _, pro in
            if pro { dismiss() }
        }
    }

    private var subtitle: String {
        switch request.trigger {
        case .lists: "Ücretsizde bir listen var. Pro ile istediğin kadar liste oluştur."
        case .share: "Listeni arkadaşlarına, öğrencilerine gönder; açan herkes kendi widget'ına ekler."
        case .rotation: "Kelimen saatte bir ya da yarım saatte bir değişsin."
        case .personalPuzzle: "Zorlandığın ve öğrendiğin kelimelerden karışık bir bulmaca."
        case .archive: "Kaçırdığın günlerin bulmacalarını çöz."
        case .examPlan: "Sınav gününe kadar her gün kaç kelime çalışman gerektiğini görelim."
        case .base: "Kurs, sınav listeleri ve Hızlı Tekrar ücretsiz kalır; Pro yenilerini ekler."
        }
    }

    private var selectedProduct: Product? {
        plan == .lifetime ? purchases.lifetime : purchases.yearly
    }

    private var ctaTitle: String {
        switch plan {
        case .lifetime: "Ömür boyu al"
        case .yearly: purchases.trialEligible ? "7 gün ücretsiz dene" : "Yıllık başla"
        }
    }

    private func planCard(_ value: Plan, title: String, price: String?, note: String, recommended: Bool) -> some View {
        let selected = plan == value
        return Button { plan = value } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                    Spacer()
                    if let price {
                        Text(price).font(KelimeFont.ui(22, weight: .bold, relativeTo: .title3))
                    } else if purchases.loadingProducts {
                        ProgressView()
                    } else {
                        Text("—").font(KelimeFont.ui(22, weight: .bold, relativeTo: .title3)).foregroundStyle(Palette.ink2)
                    }
                }
                Text(note).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(Palette.ink)
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : Palette.line, lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if recommended {
                    Text("Önerilen")
                        .font(KelimeFont.ui(11, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .offset(x: -14, y: -10)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func buy() async {
        guard let product = selectedProduct else { return }
        working = true
        defer { working = false }
        switch await purchases.purchase(product) {
        case .purchased: dismiss()
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
    /// "Öneri gönder" in Ayarlar.
    static let feedbackURL = URL(string: "https://github.com/enesseval/kelime/issues")!
    static let termsURL = URL(string: "https://enesseval.github.io/kelime/kosullar.html")!
    static let privacyURL = URL(string: "https://enesseval.github.io/kelime/gizlilik.html")!
}
