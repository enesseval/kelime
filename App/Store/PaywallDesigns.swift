import KelimeCore
import KelimeUI
import RevenueCat
import SwiftUI

/// Paywall designs drawn with the app's own pages, cards and type, to compare with the night
/// sky one (`PaywallView`). Opened from Geliştirici › Paywall tasarımları; the live paywall is
/// `WidgetPaywall`.
enum PaywallDesign: String, CaseIterable, Identifiable {
    case sky, wordCard, settings, widget, compare, puzzle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sky: "Gece gökyüzü (eski)"
        case .wordCard: "Kelime kartı"
        case .settings: "Ayarlar listesi"
        case .widget: "Widget önizlemesi (kullanılan)"
        case .compare: "Ücretsiz / Pro tablosu"
        case .puzzle: "Bulmaca"
        }
    }

    var detail: String {
        switch self {
        case .sky: "Koyu, onboarding'deki gökyüzüyle"
        case .wordCard: "\"pro\" kelimesi Bugün'deki kart gibi; plan seçimi segmentli"
        case .settings: "Ayarlar'daki bölümler gibi sade, en yerli duran"
        case .widget: "Kilit ekranı widget'ı: Normal ile Çok sık yan yana"
        case .compare: "Neyin ücretsiz kalıp neyin Pro olduğu tek bakışta"
        case .puzzle: "Bulmaca ızgarasında PRO, özellikler kutucuklarda"
        }
    }
}

/// Geliştirici › Paywall tasarımları: opens each design over the app, as the paywall would.
struct PaywallGalleryView: View {
    @Environment(AppModel.self) private var app
    @State private var shown: PaywallDesign?
    @State private var trigger: PaywallTrigger = .base

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Her tasarım gerçek ürünler ve fiyatlarla açılır; satın alma da çalışır. Açılış sebebi başlığı ve öne çıkan özelliği değiştirir.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                SettingsSection("AÇILIŞ SEBEBİ") {
                    SettingsRow("Tetikleyici") {
                        Picker("", selection: $trigger) {
                            ForEach(PaywallTrigger.allCases) { trigger in
                                Text(trigger.headline()).tag(trigger)
                            }
                        }
                        .labelsHidden()
                        .tint(Palette.ink2)
                    }
                }
                ForEach(PaywallDesign.allCases) { design in
                    Button { shown = design } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(design.title).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                                Text(design.detail).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                        }
                        .foregroundStyle(Palette.ink)
                        .surfaceCard(radius: 18, padding: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("Paywall tasarımları")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shown) { design in
            PaywallDesignView(design: design, request: AppRouter.PaywallRequest(trigger: trigger)).environment(app)
        }
    }
}

struct PaywallDesignView: View {
    let design: PaywallDesign
    let request: AppRouter.PaywallRequest

    var body: some View {
        switch design {
        case .sky: PaywallView(request: request)
        case .wordCard: WordCardPaywall(request: request)
        case .settings: SettingsPaywall(request: request)
        case .widget: WidgetPaywall(request: request)
        case .compare: ComparePaywall(request: request)
        case .puzzle: PuzzlePaywall(request: request)
        }
    }
}

// MARK: - Shared pieces

enum PaywallPlan: CaseIterable {
    case monthly, annual, lifetime

    var title: String {
        switch self {
        case .monthly: "Aylık"
        case .annual: "Yıllık"
        case .lifetime: "Ömür boyu"
        }
    }
}

extension PurchaseManager {
    func package(_ plan: PaywallPlan) -> Package? {
        switch plan {
        case .monthly: monthly
        case .annual: annual
        case .lifetime: lifetime
        }
    }

    func price(_ plan: PaywallPlan) -> String? { package(plan)?.storeProduct.localizedPriceString }

    /// Short line under a plan: "ayda …", "7 gün ücretsiz", "tek seferlik".
    func note(_ plan: PaywallPlan) -> String {
        switch plan {
        case .monthly: "Her ay yenilenir"
        case .annual:
            [trialEligible ? "7 gün ücretsiz" : nil, annual?.storeProduct.localizedPricePerMonth.map { "ayda \($0)" }]
                .compactMap { $0 }.joined(separator: " · ")
        case .lifetime: "Tek seferlik ödeme"
        }
    }

    func ctaTitle(_ plan: PaywallPlan) -> String {
        switch plan {
        case .annual:
            if trialEligible { return "7 gün ücretsiz dene" }
            return price(.annual).map { "Abone ol · \($0)/yıl" } ?? "Abone ol"
        case .monthly: return price(.monthly).map { "Abone ol · \($0)/ay" } ?? "Abone ol"
        case .lifetime: return price(.lifetime).map { "Satın al · \($0)" } ?? "Satın al"
        }
    }

    /// "%41 tasarruf" on the annual plan.
    var savingBadge: String? { annualSaving.map { "%\($0) tasarruf" } }
}

/// What every design shares: the close button, the buy button with its fixed two-line note and
/// the restore and legal links, the purchase itself and closing once Pro.
struct PaywallFrame<Content: View>: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Binding var plan: PaywallPlan
    /// Lays the content out on one screen without scrolling; a flexible part (the widget
    /// preview) takes what is left. Very short screens still scroll.
    var fitsScreen = false
    @ViewBuilder let content: Content
    @State private var working = false
    @State private var toast: String?

    private var purchases: PurchaseManager { app.purchases }

    var body: some View {
        Group {
            if fitsScreen {
                GeometryReader { geo in
                    if geo.size.height >= 560 {
                        VStack(spacing: 14) { content }
                            .padding(.horizontal, 20)
                            .padding(.top, 46)
                            .padding(.bottom, 10)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    } else {
                        scrolling
                    }
                }
            } else {
                scrolling
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 34, height: 34)
                    .background(Palette.surface2, in: Circle())
            }
            .frame(width: 44, height: 44)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .accessibilityLabel("Kapat")
        }
        .screenBackground()
        .toast($toast)
        .task { await purchases.loadProducts() }
        .onChange(of: purchases.isPro) { _, pro in if pro { dismiss() } }
    }

    /// Under the button: what is billed and when (App Store guideline 3.1.2), two lines for
    /// every plan.
    private var legalNote: String {
        switch plan {
        case .lifetime:
            return "Tek seferlik ödeme; abonelik değildir, yenilenmez. Satın alımın Geri yükle ile her cihazına gelir."
        case .annual where purchases.trialEligible:
            let price = purchases.price(.annual).map { "yılda \($0)" } ?? "yıllık ücret"
            return "7 gün ücretsiz, sonra \(price). Deneme bitmeden en az 24 saat önce iptal edersen ücret alınmaz."
        case .annual, .monthly:
            return "Abonelik, dönem bitmeden en az 24 saat önce iptal edilmezse yenilenir. Ayarlar › Apple Kimliği › Abonelikler'den yönetilir."
        }
    }

    private var scrolling: some View {
        ScrollView {
            VStack(spacing: 20) { content }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button { Task { await buy() } } label: {
                if working { ProgressView().tint(Palette.onAccent) } else { Text(purchases.ctaTitle(plan)) }
            }
            .buttonStyle(PrimaryButtonStyle(height: 54))
            .disabled(working || purchases.package(plan) == nil)
            .opacity(purchases.package(plan) == nil ? 0.6 : 1)
            Text(legalNote)
                .font(KelimeFont.ui(11, relativeTo: .caption2))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.9)
            HStack(spacing: 18) {
                Button("Geri yükle") { Task { await restore() } }
                Button("Koşullar") { openURL(Legal.termsURL) }
                Button("Gizlilik") { openURL(Legal.privacyURL) }
            }
            .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: 28)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Palette.background.opacity(0.97).ignoresSafeArea())
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private func buy() async {
        guard let package = purchases.package(plan) else { return }
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
        toast = await purchases.restore() ? "Pro geri yüklendi" : (purchases.lastError ?? "Geri yüklenecek satın alma bulunamadı")
    }
}

/// The features in the order that puts the paywall's reason first.
private func orderedFeatures(for trigger: PaywallTrigger) -> [PaywallView.Feature] {
    let focus: String? = switch trigger {
    case .lists: "lists"
    case .share: "share"
    case .examPlan: "exam"
    case .rotation: "rotation"
    case .personalPuzzle, .archive: "puzzle"
    case .discover: "discover"
    case .base: nil
    }
    guard let focus else { return PaywallView.features }
    return PaywallView.features.filter { $0.id == focus } + PaywallView.features.filter { $0.id != focus }
}

private func isFocus(_ feature: PaywallView.Feature, _ trigger: PaywallTrigger) -> Bool {
    trigger != .base && orderedFeatures(for: trigger).first?.id == feature.id
}

/// Plan rows as on Ayarlar: one card, a radio per plan.
private struct PlanList: View {
    @Environment(AppModel.self) private var app
    @Binding var plan: PaywallPlan

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(PaywallPlan.allCases.enumerated()), id: \.element) { index, option in
                if index > 0 { Divider().overlay(Palette.line) }
                Button { withAnimation(.snappy) { plan = option } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: plan == option ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(plan == option ? Palette.accent : Palette.ink2.opacity(0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(option.title).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                                if option == .annual, let badge = app.purchases.savingBadge { SavingBadge(text: badge) }
                            }
                            Text(app.purchases.note(option)).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                        }
                        Spacer()
                        PriceText(price: app.purchases.price(option))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(plan == option ? .isSelected : [])
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line))
    }
}

/// Three plan tiles side by side.
private struct PlanTiles: View {
    @Environment(AppModel.self) private var app
    @Binding var plan: PaywallPlan

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PaywallPlan.allCases, id: \.self) { option in
                let selected = plan == option
                Button { withAnimation(.snappy) { plan = option } } label: {
                    VStack(spacing: 6) {
                        Text(option.title).font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                        PriceText(price: app.purchases.price(option), size: 18)
                        Text(app.purchases.note(option))
                            .font(KelimeFont.ui(11, relativeTo: .caption2))
                            .foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.center)
                            .lineLimit(2, reservesSpace: true)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .background(selected ? Palette.accentSoft : Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? Palette.accent : Palette.line, lineWidth: selected ? 2 : 1))
                    .overlay(alignment: .top) {
                        if option == .annual, let badge = app.purchases.savingBadge { SavingBadge(text: badge).offset(y: -9) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.top, 8)
    }
}

private struct SavingBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(KelimeFont.ui(10, weight: .bold))
            .foregroundStyle(Palette.greenInk)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(Palette.greenBackground, in: Capsule())
    }
}

private struct PriceText: View {
    @Environment(AppModel.self) private var app
    let price: String?
    var size: CGFloat = 17

    var body: some View {
        if let price {
            Text(price).font(KelimeFont.ui(size, weight: .bold, relativeTo: .headline)).minimumScaleFactor(0.7).lineLimit(1)
        } else if app.purchases.loadingProducts {
            ProgressView()
        } else {
            Text("—").font(KelimeFont.ui(size, weight: .bold)).foregroundStyle(Palette.ink2)
        }
    }
}

private struct Kicker: View {
    var text = "KELİME WIDGET PRO"

    var body: some View {
        Text(text)
            .font(KelimeFont.ui(12, weight: .bold, relativeTo: .caption))
            .tracking(1.2)
            .foregroundStyle(Palette.accent)
    }
}

private func subtitle(_ trigger: PaywallTrigger) -> String {
    switch trigger {
    case .lists: "Ücretsizde bir listen var. Pro ile istediğin kadar liste oluştur."
    case .share: "Listeni linkle gönder ya da Keşfet'te herkese aç."
    case .rotation: "Kilit ekranında gün boyu daha çok kelime."
    case .personalPuzzle: "Zorlandığın ve öğrendiğin kelimelerden karışık bir bulmaca."
    case .archive: "Kaçırdığın günlerin bulmacalarını çöz."
    case .examPlan: "Sınav gününe kadar her gün kaç kelime çalışman gerektiğini görelim."
    case .discover: "Diğer öğrencilerin hazırladığı listeleri ekle; widget'ında dönsün."
    case .base: "Kurs, sınav listeleri ve Hızlı Tekrar ücretsiz kalır; Pro yenilerini ekler."
    }
}

// MARK: - 1. Kelime kartı

/// "pro" as a word on Bugün's card, the features as its senses, plans in a segmented control.
struct WordCardPaywall: View {
    let request: AppRouter.PaywallRequest
    @Environment(AppModel.self) private var app
    @State private var plan: PaywallPlan = .annual

    var body: some View {
        PaywallFrame(plan: $plan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("KELİME WIDGET PRO")
                        .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                        .tracking(0.7)
                        .foregroundStyle(Palette.ink2)
                    Spacer()
                    Text("PRO")
                        .font(KelimeFont.ui(11, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Text("pro").font(KelimeFont.english(64, relativeTo: .largeTitle)).tracking(-1.5)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("adj.").font(KelimeFont.english(20, relativeTo: .title3)).italic().foregroundStyle(Palette.ink2)
                    Text(request.trigger == .base ? "bir adım önde; daha çok kelime, daha çok liste" : request.trigger.headline(deck: request.deck).lowercased(with: Locale(identifier: "tr_TR")))
                        .font(KelimeFont.ui(19, relativeTo: .title3))
                }
                Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 4)
                Text("Every word sticks a little faster.").font(KelimeFont.english(21, relativeTo: .title3)).italic()
                Text(subtitle(request.trigger)).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(padding: 22)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(orderedFeatures(for: request.trigger).enumerated()), id: \.element.id) { index, feature in
                    if index > 0 { Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 44) }
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(KelimeFont.english(20, relativeTo: .body))
                            .foregroundStyle(isFocus(feature, request.trigger) ? Palette.accent : Palette.ink2)
                            .frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title).font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                            Text(feature.detail).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 11)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                SegmentedPicker(options: PaywallPlan.allCases, selection: $plan) { $0.title }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(plan.title).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                            if plan == .annual, let badge = app.purchases.savingBadge { SavingBadge(text: badge) }
                        }
                        Text(app.purchases.note(plan)).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    PriceText(price: app.purchases.price(plan), size: 22)
                }
                .foregroundStyle(Palette.ink)
                .surfaceCard(radius: 16, padding: 16)
            }
        }
    }
}

// MARK: - 2. Ayarlar listesi

/// The plainest: sections and rows exactly like Ayarlar.
struct SettingsPaywall: View {
    let request: AppRouter.PaywallRequest
    @State private var plan: PaywallPlan = .annual

    var body: some View {
        PaywallFrame(plan: $plan) {
            VStack(alignment: .leading, spacing: 6) {
                Kicker()
                Text(request.trigger.headline(deck: request.deck))
                    .font(KelimeFont.ui(32, weight: .bold, relativeTo: .largeTitle))
                    .tracking(-0.6)
                Text(subtitle(request.trigger)).font(KelimeFont.ui(15, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsSection("PRO İLE GELENLER") {
                ForEach(Array(orderedFeatures(for: request.trigger).enumerated()), id: \.element.id) { index, feature in
                    if index > 0 { Divider().overlay(Palette.line) }
                    HStack(spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                            .frame(width: 30, height: 30)
                            .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink)
                            Text(feature.detail).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            SettingsSection("ÜCRETSİZ KALANLAR") {
                Text("Kurs ve bölümler · sınav listeleri · sınırsız Hızlı Tekrar · günün bulmacası · bir kendi listen · Keşfet'e göz atmak")
                    .font(KelimeFont.ui(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("PLAN")
                    .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                    .tracking(0.7)
                    .foregroundStyle(Palette.ink2)
                    .padding(.leading, 4)
                PlanList(plan: $plan)
            }
        }
    }
}

// MARK: - 3. Widget önizlemesi

/// A lock screen widget changing words, Normal against Çok sık.
struct WidgetPaywall: View {
    let request: AppRouter.PaywallRequest
    @State private var plan: PaywallPlan = .annual
    @State private var tick = 0
    private let words = [("resilient", "dayanıklı"), ("eager", "istekli"), ("thrive", "gelişmek"), ("subtle", "ince, belli belirsiz"), ("vivid", "canlı")]

    var body: some View {
        PaywallFrame(plan: $plan, fitsScreen: true) {
            VStack(spacing: 6) {
                Kicker()
                Text(request.trigger.headline(deck: request.deck))
                    .font(KelimeFont.english(32, relativeTo: .largeTitle))
                    .tracking(-0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle(request.trigger))
                    .font(KelimeFont.ui(13, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.ink)

            // The lock screen preview gives way first: it takes whatever height is left.
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Text("09:41")
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(Palette.ink)
                let word = words[tick % words.count]
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.0).font(KelimeFont.english(22, relativeTo: .title2))
                    Text(word.1).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                }
                .id(tick)
                .transition(.push(from: .bottom).combined(with: .opacity))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    rate("Normal", "günde 4'e kadar", pro: false)
                    rate("Çok sık", "günde 24'e kadar", pro: true)
                }
                .padding(.horizontal, 12)
            }
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 190, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [Palette.accentSoft, Palette.surface], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.line))
            .clipped()
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(.snappy) { tick += 1 }
                }
            }

            FlowChips(features: orderedFeatures(for: request.trigger), trigger: request.trigger)
            PlanTiles(plan: $plan)
        }
    }

    private func rate(_ title: String, _ detail: String, pro: Bool) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(title).font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                if pro { ProBadge() }
            }
            Text(detail).font(KelimeFont.ui(11, relativeTo: .caption2)).foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(pro ? Palette.surface : Palette.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(pro ? Palette.accent : .clear))
    }
}

/// Features as wrapped chips.
private struct FlowChips: View {
    let features: [PaywallView.Feature]
    let trigger: PaywallTrigger

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            ForEach(features) { feature in
                let focus = isFocus(feature, trigger)
                HStack(spacing: 8) {
                    Image(systemName: feature.symbol).font(.system(size: 13, weight: .semibold))
                    Text(feature.title).font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote)).lineLimit(2).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(focus ? Palette.onAccent : Palette.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(focus ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(focus ? .clear : Palette.line))
            }
        }
    }
}

// MARK: - 4. Ücretsiz / Pro tablosu

/// What stays free and what Pro adds, side by side.
struct ComparePaywall: View {
    let request: AppRouter.PaywallRequest
    @State private var plan: PaywallPlan = .annual

    private let rows: [(String, String, String)] = [
        ("Kurs, bölümler ve hikâyeler", "✓", "✓"),
        ("Sınav listeleri (YDS, YÖKDİL, IELTS)", "✓", "✓"),
        ("Hızlı Tekrar", "Sınırsız", "Sınırsız"),
        ("Günün bulmacası", "✓", "✓"),
        ("Kendi listen", "1", "Sınırsız"),
        ("Keşfet'ten liste eklemek", "—", "✓"),
        ("Listeni paylaşmak", "—", "✓"),
        ("Widget'ta yeni kelime", "Günde 4", "Günde 24"),
        ("Sınav planı", "—", "✓"),
        ("Sana özel bulmaca ve arşiv", "—", "✓"),
    ]

    var body: some View {
        PaywallFrame(plan: $plan) {
            VStack(alignment: .leading, spacing: 6) {
                Kicker()
                Text(request.trigger.headline(deck: request.deck))
                    .font(KelimeFont.english(34, relativeTo: .largeTitle))
                    .tracking(-0.8)
                Text(subtitle(request.trigger)).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Ücretsiz").frame(width: 70)
                    Text("Pro").foregroundStyle(Palette.accent).frame(width: 70)
                }
                .font(KelimeFont.ui(12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                ForEach(rows, id: \.0) { row in
                    Divider().overlay(Palette.line)
                    HStack {
                        Text(row.0).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        cell(row.1, pro: false)
                        cell(row.2, pro: true)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                }
            }
            .background(alignment: .trailing) {
                Rectangle().fill(Palette.accentSoft).frame(width: 70).padding(.trailing, 14)
            }
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line))

            PlanTiles(plan: $plan)
        }
    }

    private func cell(_ value: String, pro: Bool) -> some View {
        Group {
            switch value {
            case "✓": Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(pro ? Palette.accent : Palette.greenInk)
            case "—": Text("—").foregroundStyle(Palette.ink2.opacity(0.6))
            default: Text(value).font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption)).foregroundStyle(pro ? Palette.accent : Palette.ink2)
            }
        }
        .frame(width: 70)
    }
}

// MARK: - 5. Bulmaca

/// PRO spelled in a crossword grid; each feature is a clue.
struct PuzzlePaywall: View {
    let request: AppRouter.PaywallRequest
    @State private var plan: PaywallPlan = .annual
    @State private var revealed = 0
    /// WORDS down, PRO across its R; WIN and SET complete the grid.
    private let grid: [[Character?]] = [
        [nil, "W", "I", "N", nil],
        [nil, "O", nil, nil, nil],
        ["P", "R", "O", nil, nil],
        [nil, "D", nil, nil, nil],
        [nil, "S", "E", "T", nil],
    ]

    var body: some View {
        PaywallFrame(plan: $plan) {
            VStack(spacing: 18) {
                VStack(spacing: 3) {
                    ForEach(0..<grid.count, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<grid[row].count, id: \.self) { column in
                                cell(grid[row][column], highlighted: row == 2 && column < 3, index: row * 5 + column)
                            }
                        }
                    }
                }
                VStack(spacing: 6) {
                    Text(request.trigger.headline(deck: request.deck))
                        .font(KelimeFont.english(32, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .multilineTextAlignment(.center)
                    Text(subtitle(request.trigger))
                        .font(KelimeFont.ui(14, relativeTo: .subheadline))
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Palette.ink)
            }
            .task {
                for step in 1...25 {
                    try? await Task.sleep(for: .milliseconds(45))
                    withAnimation(.snappy) { revealed = step }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("İPUÇLARI")
                    .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                    .tracking(0.7)
                    .foregroundStyle(Palette.ink2)
                    .padding(.bottom, 8)
                ForEach(Array(orderedFeatures(for: request.trigger).enumerated()), id: \.element.id) { index, feature in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)").font(KelimeFont.ui(12, weight: .bold)).foregroundStyle(Palette.accent).frame(width: 18)
                        Text(feature.title).font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                            + Text(" · " + feature.detail).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(radius: 18, padding: 16)

            PlanList(plan: $plan)
        }
    }

    private func cell(_ letter: Character?, highlighted: Bool, index: Int) -> some View {
        ZStack {
            if let letter {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlighted ? Palette.accent : Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(highlighted ? .clear : Palette.line))
                Text(String(letter))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(highlighted ? Palette.onAccent : Palette.ink)
                    .opacity(index < revealed ? 1 : 0)
                    .scaleEffect(index < revealed ? 1 : 0.6)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}
