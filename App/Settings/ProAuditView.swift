import KelimeCore
import KelimeUI
import SwiftUI

/// Geliştirici › Pro vaatleri: every promise on the paywall, checked against the real code.
/// The checks run on a copy of the database, as a free user and as Pro, so nothing changes.
struct ProAuditView: View {
    @Environment(AppModel.self) private var app
    @State private var items: [ProAuditItem]?
    @State private var running = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paywall'da söz verdiğimiz her şey, uygulamanın gerçek kodu üzerinden ölçülür: önce ücretsiz kullanıcı, sonra Pro olarak. Verilerin bir kopyası kullanılır; hiçbir şey değişmez.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                if let items {
                    summary(items)
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider().overlay(Palette.line) }
                            row(item)
                        }
                    }
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line))
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                }
                Button("Yeniden kontrol et") { Task { await run() } }
                    .buttonStyle(PrimaryButtonStyle(height: 50))
                    .disabled(running)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationTitle("Pro vaatleri")
        .navigationBarTitleDisplayMode(.inline)
        .task { await run() }
    }

    private func summary(_ items: [ProAuditItem]) -> some View {
        let failed = items.filter { !$0.passed }.count
        return HStack(spacing: 10) {
            Image(systemName: failed == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(failed == 0 ? Palette.green : Palette.amber)
            Text(failed == 0 ? "\(items.count) vaadin hepsi çalışıyor" : "\(failed) vaat çalışmıyor")
                .font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Palette.ink)
        }
    }

    private func row(_ item: ProAuditItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(size: 20))
                .foregroundStyle(item.passed ? Palette.green : Color.red)
                .accessibilityLabel(item.passed ? "Çalışıyor" : "Çalışmıyor")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.promise)
                    .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(Palette.ink)
                Text(item.detail)
                    .font(KelimeFont.ui(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private func run() async {
        guard let database = app.database else { return }
        running = true
        defer { running = false }
        let clock = app.clock
        let reader = database.reader
        var result = await Task.detached { ProAudit.run(source: reader, clock: clock) }.value
        result.insert(contentsOf: [await archiveItem(), gatesItem()], at: 5)
        items = result
    }

    /// The archive has a playable puzzle for each of the last 30 days.
    private func archiveItem() async -> ProAuditItem {
        let clock = app.clock
        let days = await app.read { db -> (count: Int, distinct: Int) in
            let prefs = try Preferences.load(db)
            let ids = (1...30).compactMap { PuzzleLibrary.daily(for: prefs.level, on: clock.today.adding(days: -$0))?.puzzle.id }
            return (ids.count, Set(ids).count)
        }
        let ok = days?.count == 30 && days?.distinct == 30
        return ProAuditItem(
            id: "archive",
            promise: "Bulmaca arşivi",
            passed: ok,
            detail: "Son 30 günün \(days?.count ?? 0) bulmacası hazır, \(days?.distinct ?? 0) tanesi farklı"
        )
    }

    /// Pro opens the Pro screens directly; free users get the paywall.
    private func gatesItem() -> ProAuditItem {
        var failures: [String] = []
        let pro = AppRouter()
        pro.openArchive(isPro: true)
        if pro.paywall != nil || pro.playPath != [.puzzleArchive] { failures.append("arşiv") }
        pro.openPersonalPuzzle(isPro: true)
        if pro.paywall != nil || pro.puzzle == nil { failures.append("özel bulmaca") }
        pro.startQuickReview(remaining: nil)
        if pro.paywall != nil || !pro.reviewPresented { failures.append("hızlı tekrar") }

        let free = AppRouter()
        free.openArchive(isPro: false)
        if free.paywall?.trigger != .archive { failures.append("arşiv paywall'u") }
        free.paywall = nil
        free.openPersonalPuzzle(isPro: false)
        if free.paywall?.trigger != .personalPuzzle { failures.append("özel bulmaca paywall'u") }
        free.paywall = nil
        free.startQuickReview(remaining: 0)
        if free.paywall?.trigger != .reviewLimit { failures.append("hızlı tekrar paywall'u") }

        return ProAuditItem(
            id: "gates",
            promise: "Pro ekranları paywall'suz açılır",
            passed: failures.isEmpty,
            detail: failures.isEmpty
                ? "Pro: arşiv, özel bulmaca, hızlı tekrar direkt açılıyor · Ücretsiz: paywall çıkıyor"
                : "Hatalı: \(failures.joined(separator: ", "))"
        )
    }
}
