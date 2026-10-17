import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

/// Geliştirici › Widget günlüğü: what iOS really does with the widget on this device.
///
/// Taps carry the entry the widget had on screen, so each one shows whether the word changed
/// on time. Timeline requests show how often iOS reloads the widget; in measurement mode the
/// widget only ever has the current word, so every change needs a reload.
struct WidgetLogView: View {
    @Environment(AppModel.self) private var app
    @State private var rows: [WidgetLogEntry] = []
    @State private var probe = false
    @State private var reminders = DevTools.checkRemindersOn
    @State private var toast: String?

    /// A timeline this soon after one of our own reloads was requested by us, not by iOS.
    private static let triggerWindow: TimeInterval = 15

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controls
                tapSummary
                timelineSummary
                logList
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationTitle("Widget günlüğü")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: exportText) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Günlüğü paylaş")
            }
        }
        .task(id: app.dataVersion) { await load() }
        .refreshable { await load() }
        .toast($toast)
    }

    // MARK: - Controls

    private var controls: some View {
        SettingsSection("ÖLÇÜM") {
            toggle("Ölçüm modu", detail: "Widget'a tek kelime verilir, iOS her değişimde yeniden ister.", isOn: Binding(
                get: { probe },
                set: { on in
                    probe = on
                    Task {
                        await app.setSetting(.widgetProbe, on ? "1" : nil)
                        WidgetCenter.shared.reloadAllTimelines()
                        toast = on ? "Ölçüm modu açık" : "Normal mod: 24 saatlik liste"
                    }
                }
            ))
            Divider().overlay(Palette.line)
            toggle("Yarım saatte bir hatırlat", detail: ":00 ve :30'da widget'a dokunmanı hatırlatır.", isOn: Binding(
                get: { reminders },
                set: { on in
                    Task {
                        let ok = await DevTools.setCheckReminders(on)
                        reminders = on && ok
                        if !ok { toast = "Bildirim izni Ayarlar'dan açılabilir" }
                    }
                }
            ))
        }
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(KelimeFont.ui(15, relativeTo: .body)).foregroundStyle(Palette.ink)
                Text(detail).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            }
        }
        .tint(Palette.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Summaries

    private var taps: [WidgetLogEntry] { rows.filter { $0.onTime != nil } }

    private var tapSummary: some View {
        let late = taps.filter { $0.onTime == false }
        let lags = late.compactMap(\.lag)
        return summaryCard(
            title: "Dokunuşlar",
            lines: taps.isEmpty
                ? ["Henüz dokunuş yok. Kilit ekranındaki widget'a dokunduğunda burada görünür."]
                : [
                    "\(taps.count) dokunuş · \(taps.count - late.count) zamanında · \(late.count) geç",
                    lags.isEmpty ? nil : "Gecikme: en çok \(Self.minutes(lags.max()!)), ortalama \(Self.minutes(lags.reduce(0, +) / Double(lags.count)))",
                ].compactMap { $0 },
            ok: taps.isEmpty ? nil : late.isEmpty
        )
    }

    /// Timeline requests iOS made on its own: not within seconds of one of our reloads.
    private var iosTimelines: [WidgetLogEntry] {
        let triggers = rows.filter { $0.kind == .appReload || $0.kind == .button }.map(\.at)
        return rows.filter { row in
            row.kind == .timeline && !triggers.contains { abs(row.at.timeIntervalSince($0)) < Self.triggerWindow }
        }
    }

    private var timelineSummary: some View {
        let requests = iosTimelines.sorted { $0.at < $1.at }
        let gaps = zip(requests, requests.dropFirst()).map { $1.at.timeIntervalSince($0.at) }.sorted()
        let dayAgo = Date().addingTimeInterval(-24 * 3600)
        var lines = ["Son 24 saatte \(requests.filter { $0.at > dayAgo }.count) istek (uygulamanın tetikledikleri hariç)"]
        if !gaps.isEmpty {
            lines.append("Aralık: en kısa \(Self.minutes(gaps.first!)), ortanca \(Self.minutes(gaps[gaps.count / 2])), en uzun \(Self.minutes(gaps.last!))")
        }
        return summaryCard(title: "iOS'un liste istekleri", lines: lines, ok: nil)
    }

    private func summaryCard(title: String, lines: [String], ok: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let ok {
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ok ? Palette.green : Palette.amber)
                }
                Text(title).font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline)).foregroundStyle(Palette.ink)
            }
            ForEach(lines, id: \.self) { line in
                Text(line).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line))
    }

    // MARK: - Log

    private var logList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("KAYITLAR").font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption)).tracking(0.7).foregroundStyle(Palette.ink2)
                Spacer()
                Button("Temizle") {
                    Task {
                        try? await app.database?.writer.write { db in try WidgetLog.clear(db: db) }
                        await load()
                    }
                }
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.accent)
            }
            if rows.isEmpty {
                Text("Kayıt yok.").font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    logRow(row)
                    Divider().overlay(Palette.line)
                }
            }
        }
    }

    private func logRow(_ row: WidgetLogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.at.formatted(.dateTime.hour().minute().second()))
                .font(KelimeFont.ui(12, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Palette.ink2)
                .frame(width: 64, alignment: .leading)
            Image(systemName: icon(row))
                .font(.system(size: 13))
                .foregroundStyle(color(row))
                .frame(width: 16)
            Text(describe(row))
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    private func icon(_ row: WidgetLogEntry) -> String {
        switch row.kind {
        case .timeline: "arrow.clockwise"
        case .appReload: "iphone"
        case .tap, .button: row.onTime == false ? "xmark.circle.fill" : "hand.tap.fill"
        }
    }

    private func color(_ row: WidgetLogEntry) -> Color {
        switch row.onTime {
        case true?: Palette.green
        case false?: .red
        case nil: Palette.ink2
        }
    }

    private func describe(_ row: WidgetLogEntry) -> String {
        Self.describe(row, triggered: isTriggered(row))
    }

    private func isTriggered(_ row: WidgetLogEntry) -> Bool {
        guard row.kind == .timeline else { return false }
        return rows.contains { ($0.kind == .appReload || $0.kind == .button) && abs(row.at.timeIntervalSince($0.at)) < Self.triggerWindow }
    }

    static func describe(_ row: WidgetLogEntry, triggered: Bool) -> String {
        switch row.kind {
        case .timeline:
            var text = "Liste istendi · \(row.source) · \(row.detail)"
            if let reloadAt = row.reloadAt { text += " · sonraki: \(reloadAt.formatted(date: .omitted, time: .shortened))" }
            return text + (triggered ? " (uygulama tetikledi)" : " (iOS)")
        case .appReload:
            return "Uygulama widget'ı yeniletti"
        case .tap, .button:
            let what = row.kind == .tap ? "Dokunuş" : "Buton (\(row.detail))"
            let shown = word(row.shownCardID)
            switch row.onTime {
            case true?:
                return "\(what) · \(row.source) · \(shown) ✓ zamanında"
            case false?:
                let lag = row.lag.map { " · \(minutes($0)) geride" } ?? ""
                return "\(what) · \(row.source) · ekranda \(shown), olması gereken \(word(row.expectedCardID))\(lag)"
            case nil:
                return "\(what) · \(row.source) · \(shown)"
            }
        }
    }

    /// "b1-reluctant" → "reluctant".
    private static func word(_ id: String?) -> String {
        guard let id else { return "?" }
        return id.split(separator: "-", maxSplits: 1).last.map(String.init) ?? id
    }

    private static func minutes(_ seconds: TimeInterval) -> String {
        seconds < 90 ? "\(Int(seconds)) sn" : "\(Int((seconds / 60).rounded())) dk"
    }

    private var exportText: String {
        rows.reversed().map { row in
            "\(row.at.formatted(.iso8601)) \(Self.describe(row, triggered: isTriggered(row)))"
        }.joined(separator: "\n")
    }

    private func load() async {
        let result = await app.read { db in
            (try WidgetLog.recent(db: db), try Settings.bool(.widgetProbe, in: db))
        }
        rows = result?.0 ?? []
        probe = result?.1 ?? false
    }
}
