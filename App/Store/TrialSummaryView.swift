import KelimeCore
import KelimeUI
import SwiftUI

/// Shown once when the 3-day free trial ends: what the learner used, what stays, and the way
/// to Pro or on for free. Nothing is deleted.
struct TrialSummaryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let request: TrialSummaryRequest
    @State private var showingPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DENEME BİTTİ")
                .font(KelimeFont.ui(12, weight: .bold, relativeTo: .caption))
                .tracking(1.2)
                .foregroundStyle(Palette.ink2)
            Text("3 günde şunları denedin")
                .font(KelimeFont.english(32, relativeTo: .largeTitle))
                .tracking(-0.6)
            if request.lines.isEmpty {
                Text("Pro özelliklerini bu 3 günde henüz kullanmadın; istediğin zaman Pro ile açabilirsin.")
                    .font(KelimeFont.ui(16, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(request.lines, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .font(KelimeFont.ui(17, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(Palette.ink)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Verilerin yerinde, hiçbir şey silinmedi.")
                if request.ownLists > 1 {
                    Text("İlk listen düzenlenebilir kalır; diğer listelerin Pro olana kadar salt okunur.")
                }
                Text("Arşivden haftada 2 bulmaca ücretsiz.")
            }
            .font(KelimeFont.ui(14, relativeTo: .subheadline))
            .foregroundStyle(Palette.ink2)
            Spacer()
            Button("Pro'ya geç") { showingPaywall = true }
                .buttonStyle(PrimaryButtonStyle(height: 52))
            Button("Ücretsiz devam et") { dismiss() }
                .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showingPaywall) {
            WidgetPaywall(request: AppRouter.PaywallRequest(trigger: .trialEnded)).environment(app)
        }
        .onChange(of: app.purchases.isPurchased) { _, bought in if bought { dismiss() } }
    }
}
