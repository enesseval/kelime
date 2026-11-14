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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DENEME BİTTİ")
                            .font(KelimeFont.ui(12, weight: .bold, relativeTo: .caption))
                            .tracking(1.2)
                            .foregroundStyle(Palette.ink2)
                        Text("3 günde şunları denedin")
                            .font(KelimeFont.english(32, relativeTo: .largeTitle))
                            .tracking(-0.6)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(request.tiles.enumerated()), id: \.offset) { index, tile in
                            tileView(tile)
                                .opacity(shown || reduceMotion ? 1 : 0)
                                .offset(y: shown || reduceMotion ? 0 : 10)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(index) * 0.05), value: shown)
                        }
                    }
                    section("Ücretsiz devam eden", items: TrialSummary.freeKept, icon: "checkmark.circle.fill", tint: Palette.green)
                    section("Pro ile açılan", items: TrialSummary.proUnlocks, icon: "lock.fill", tint: Palette.accent)
                    Text("Verilerin yerinde, hiçbir şey silinmedi.")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 4) {
                Button("Pro'ya geç") { showingPaywall = true }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                Button("Ücretsiz devam et") { dismiss() }
                    .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .onAppear { shown = true }
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showingPaywall) {
            WidgetPaywall(request: AppRouter.PaywallRequest(trigger: .trialEnded)).environment(app)
        }
        .onChange(of: app.purchases.isPurchased) { _, bought in if bought { dismiss() } }
    }

    private func tileView(_ tile: TrialTile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tile.value)
                .font(KelimeFont.english(34, relativeTo: .title))
                .foregroundStyle(Palette.ink)
            Text(tile.label)
                .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func section(_ title: String, items: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(KelimeFont.ui(13, weight: .bold, relativeTo: .footnote))
                .tracking(0.6)
                .foregroundStyle(Palette.ink2)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
                    Text(item).foregroundStyle(Palette.ink)
                }
                .font(KelimeFont.ui(16, weight: .medium, relativeTo: .body))
            }
        }
    }
}
