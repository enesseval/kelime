import KelimeCore
import KelimeUI
import SwiftUI

/// Bugün's streak chip: "🔒 12 gün", amber while today still needs a round.
struct StreakBadge: View {
    let status: StreakStatus

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.studiedToday ? "lock.fill" : "lock.open")
                .font(.system(size: 11, weight: .bold))
            Text("\(status.current) gün")
                .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                .monospacedDigit()
        }
        .foregroundStyle(status.atRisk ? Palette.amberInk : Palette.ink)
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(status.atRisk ? Palette.amberBackground : Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(status.atRisk ? .clear : Palette.line))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.atRisk ? "Seri \(status.current) gün, bugün henüz çalışmadın" : "Seri \(status.current) gün")
    }
}

/// The streak page: current and longest streak, the last five weeks, and how freezes work.
struct StreakView: View {
    @Environment(AppModel.self) private var model
    @State private var status: StreakStatus?
    @State private var sharing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(status.current)")
                            .font(KelimeFont.english(88, relativeTo: .largeTitle))
                            .tracking(-2)
                            .monospacedDigit()
                        Text(status.current == 0 ? "Bugün bir tur yap, serin başlasın." : "günlük seri")
                            .font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                        Text(subtitle(status))
                            .font(KelimeFont.ui(14, relativeTo: .subheadline))
                            .foregroundStyle(status.atRisk ? Palette.amberInk : Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    StreakCalendar(status: status, today: model.clock.today)
                        .surfaceCard(padding: 16)
                    VStack(alignment: .leading, spacing: 10) {
                        rule("checkmark.circle", "Bir Hızlı Tekrar turu, Günün Bulmacası'nda bir kelime ya da bir oyun günü sayar.")
                        rule("snowflake", "Haftada \(Streak.freezes(isPro: model.isPro)) gün kaçırırsan serin bozulmaz; o gün kesik çizgiyle görünür.")
                        rule("rectangle.on.rectangle", "Widget'a bakmak seriyi saymaz ama kelimeleri o öğretir.")
                    }
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    if status.current > 0 {
                        Button { sharing = true } label: {
                            Label("Serini paylaş", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(TintedButtonStyle(height: 48))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("Seri")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.dataVersion) {
            let clock = model.clock
            status = await model.read { db in try Streak.status(db: db, clock: clock) }
        }
        .sheet(isPresented: $sharing) {
            if let status {
                ShareImageSheet(title: "Seri", name: "\(status.current) günlük seri") { style in
                    StreakShareCard(status: status, today: model.clock.today, style: style)
                }
            }
        }
    }

    private func subtitle(_ status: StreakStatus) -> String {
        if status.atRisk { return "Bugün henüz çalışmadın. 2 dakikalık bir tur serini korur." }
        if status.longest > status.current { return "En uzun serin: \(status.longest) gün" }
        return status.current > 0 ? "Bu senin en uzun serin." : ""
    }

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).frame(width: 18)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Five weeks, Monday first: filled dot = studied, dashed ring = covered by a freeze.
struct StreakCalendar: View {
    let status: StreakStatus
    let today: LocalDate
    var dot: CGFloat = 30
    var ink: Color = Palette.ink

    private static let initials = ["P", "S", "Ç", "P", "C", "C", "P"]

    var body: some View {
        let start = StatsQueries.weekStart(for: today).adding(days: -28)
        let frozen = Set(status.frozenDays)
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Self.initials[i])
                        .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<5, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = start.adding(days: week * 7 + weekday)
                        cell(day, studied: status.studiedDays.contains(day), frozen: frozen.contains(day))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Son beş haftada \(status.studiedDays.count) gün çalıştın")
    }

    @ViewBuilder
    private func cell(_ day: LocalDate, studied: Bool, frozen: Bool) -> some View {
        ZStack {
            if studied {
                Circle().fill(Palette.green)
            } else if frozen {
                Circle().strokeBorder(Palette.ink2, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else if day > today {
                Circle().fill(.clear)
            } else {
                Circle().fill(Palette.surface2)
            }
            if day == today {
                Circle().strokeBorder(Palette.accent, lineWidth: 2).padding(-3)
            }
        }
        .frame(width: dot, height: dot)
    }
}

/// The streak as a share image.
struct StreakShareCard: View {
    let status: StreakStatus
    let today: LocalDate
    let style: ShareCardStyle

    var body: some View {
        ShareFrame(style: style) {
            Spacer().frame(height: 40)
            Text("SERİ")
                .font(KelimeFont.ui(14, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.ink2)
            Text("\(status.current)")
                .font(KelimeFont.english(140))
                .tracking(-4)
                .padding(.top, 4)
            Text("gün üst üste İngilizce")
                .font(KelimeFont.ui(22, weight: .semibold))
            StreakCalendar(status: status, today: today, dot: 26)
                .padding(.top, 40)
        }
    }
}

/// Monday's look back at last week, with a share button.
struct WeeklySummaryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var summary: WeeklySummary?
    @State private var sharing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let summary {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(WeeklySummaryView.range(summary.weekStart))
                            .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(Palette.ink2)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(summary.learned)").font(KelimeFont.english(72, relativeTo: .largeTitle)).tracking(-1.5)
                            Text("kelime öğrendin").font(KelimeFont.ui(18, weight: .semibold, relativeTo: .headline))
                        }
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                stat("\(summary.widgetWords)", "kelime kilit ekranında göründü")
                                stat("\(summary.streak) gün", "seri")
                            }
                            GridRow {
                                stat(summary.accuracy.map { "%\(Int(($0 * 100).rounded()))" } ?? "–", "Hızlı Tekrar doğruluğu")
                                stat("\(summary.struggling)", "kelimede zorlandın")
                            }
                        }
                        if let word = summary.wordOfTheWeek {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("HAFTANIN KELİMESİ")
                                    .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                                    .tracking(0.9)
                                    .foregroundStyle(Palette.ink2)
                                Text(word.word).font(KelimeFont.english(34, relativeTo: .title))
                                Text("\(word.pos.label) · \(word.meaning)").font(KelimeFont.ui(15, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                                Text("Önce zorlandın, sonunda öğrendin.").font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.greenInk)
                            }
                            .surfaceCard(padding: 16)
                        }
                        Button {
                            sharing = true
                            Analytics.signal("weekly.shared")
                        } label: {
                            Label("Haftanı paylaş", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle(height: 52))
                    }
                    .padding(20)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .screenBackground()
            .navigationTitle("Geçen hafta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { dismiss() }.fontWeight(.semibold) }
            }
            .task {
                let clock = model.clock
                summary = await model.read { db in try WeeklySummary.lastWeek(db: db, clock: clock) }
                await model.write(rebuildQueue: false) { db in try WeeklySummary.markSeen(db: db, clock: clock) }
                Analytics.signal("weekly.opened")
            }
            .sheet(isPresented: $sharing) {
                if let summary {
                    ShareImageSheet(title: "Haftalık özet", name: "Geçen haftam") { style in
                        WeeklyShareCard(summary: summary, style: style)
                    }
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(KelimeFont.ui(22, weight: .bold, relativeTo: .title3)).monospacedDigit()
            Text(label).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .surfaceCard(padding: 14)
    }

    /// "27 Ekim – 2 Kasım".
    static func range(_ start: LocalDate) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        let calendar = Calendar.current
        return f.string(from: start.startDate(in: calendar)) + " – " + f.string(from: start.adding(days: 6).startDate(in: calendar))
    }
}

/// Bugün's Monday card that opens last week's summary.
struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 44, height: 44)
                    .background(Palette.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Geçen haftan hazır").font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                    Text("\(summary.learned) kelime öğrendin · \(summary.widgetWords) kelime kilit ekranında")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(Palette.ink)
            .surfaceCard(padding: 16)
        }
        .buttonStyle(.plain)
    }
}

/// The weekly summary as a share image.
struct WeeklyShareCard: View {
    let summary: WeeklySummary
    let style: ShareCardStyle

    var body: some View {
        ShareFrame(style: style) {
            Spacer().frame(height: 30)
            Text("GEÇEN HAFTAM")
                .font(KelimeFont.ui(14, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.ink2)
            Text(WeeklySummaryView.range(summary.weekStart))
                .font(KelimeFont.ui(15))
                .foregroundStyle(Palette.ink2)
                .padding(.top, 2)
            Text("\(summary.learned)")
                .font(KelimeFont.english(120))
                .tracking(-3)
                .padding(.top, 18)
            Text("yeni kelime").font(KelimeFont.ui(24, weight: .semibold))
            VStack(alignment: .leading, spacing: 10) {
                line("\(summary.widgetWords)", "kelime kilit ekranımda göründü")
                line("\(summary.streak) gün", "seri")
            }
            .padding(.top, 28)
            if let word = summary.wordOfTheWeek {
                Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 24)
                Text("HAFTANIN KELİMESİ").font(KelimeFont.ui(12, weight: .bold)).tracking(1.2).foregroundStyle(Palette.ink2)
                Text(word.word).font(KelimeFont.english(40)).padding(.top, 4)
                Text(word.meaning).font(KelimeFont.ui(17)).foregroundStyle(Palette.ink2)
            }
        }
    }

    private func line(_ value: String, _ label: String) -> some View {
        (Text(value).font(KelimeFont.ui(20, weight: .bold)) + Text("  " + label).font(KelimeFont.ui(17)).foregroundColor(Palette.ink2))
    }
}
