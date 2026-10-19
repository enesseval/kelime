import KelimeCore
import KelimeUI
import SwiftUI

/// "A1 yolu" on Oyna: how far the learner is in the course, and the way in.
struct CourseCard: View {
    let level: CEFRLevel
    let units: [UnitProgress]

    var body: some View {
        let started = units.filter(\.started)
        let finished = units.filter(\.isFinished)
        // Average of the units, so a card shared by two units is not counted twice.
        let fraction = units.isEmpty ? 0 : units.map(\.fraction).reduce(0, +) / Double(units.count)
        NavigationLink(value: Route.course(level)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(level.rawValue) yolu").font(KelimeFont.english(30, relativeTo: .title))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                }
                Text("\(units.count) bölüm · \(started.count) başladı · \(finished.count) bitti")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                ThinProgressBar(fraction: fraction)
                    .padding(.top, 4)
            }
            .foregroundStyle(Palette.ink)
            .surfaceCard(padding: 20)
        }
        .buttonStyle(.plain)
    }
}

/// The level's units: core first, the any-order units, the bridge last.
struct CourseView: View {
    @Environment(AppModel.self) private var model
    let level: CEFRLevel
    @State private var units: [UnitProgress] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Önce çekirdek, sonra istediğin bölüm. Başladığın bölümlerin kelimeleri widget'ına gelir.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .padding(.bottom, 4)
                ForEach(units) { item in
                    NavigationLink(value: Route.unit(item.unit.id)) { row(item) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("\(level.rawValue) yolu")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.dataVersion) {
            let level = level
            units = await model.read { db in try Curriculum.progress(level: level, db: db) } ?? []
        }
    }

    private func row(_ item: UnitProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.unit.title).font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                Spacer()
                status(item)
            }
            Text(item.unit.goal)
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let hint = placementHint(item.unit.placement) {
                Text(hint).font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption)).foregroundStyle(Palette.accent)
            }
            if item.started {
                ThinProgressBar(fraction: item.fraction).padding(.top, 2)
            }
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 18, padding: 16)
    }

    @ViewBuilder
    private func status(_ item: UnitProgress) -> some View {
        if item.isFinished {
            Text("Bitti ✓").font(KelimeFont.ui(12, weight: .semibold)).foregroundStyle(Palette.greenInk)
        } else if item.started {
            Text("\(item.learned)/\(item.total)").font(KelimeFont.ui(12, weight: .semibold)).foregroundStyle(Palette.ink2)
        } else {
            Text("\(item.total) kart").font(KelimeFont.ui(12)).foregroundStyle(Palette.ink2)
        }
    }

    private func placementHint(_ placement: UnitPlacement) -> String? {
        switch placement {
        case .first: "Herkes buradan başlar"
        case .last: "Diğer bölümlerden sonra önerilir"
        case .any: nil
        }
    }
}

/// One unit: its goal, the start button, stories, phrases and words.
struct UnitView: View {
    @Environment(AppModel.self) private var model
    let unitID: String
    @State private var unit: CurriculumUnit?
    @State private var cards: [Card] = []
    @State private var started = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            if let unit {
                VStack(alignment: .leading, spacing: 18) {
                    Text(unit.goal)
                        .font(KelimeFont.ui(16, relativeTo: .body))
                        .foregroundStyle(Palette.ink2)
                    startButton(unit)
                    storiesSection(unit)
                    cardSection("KALIPLAR", cards.filter(\.isPhrase))
                    cardSection("KELİMELER", cards.filter { !$0.isPhrase })
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .screenBackground()
        .navigationTitle(unit?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.dataVersion) {
            let id = unitID
            let loaded = await model.read { db -> (CurriculumUnit?, [Card], Bool) in
                (try CurriculumUnit.fetchOne(db, key: id), try Curriculum.cards(of: id, db: db),
                 try Curriculum.started(db: db).contains(id))
            }
            unit = loaded?.0
            cards = loaded?.1 ?? []
            started = loaded?.2 ?? false
        }
        .toast($toast)
    }

    @ViewBuilder
    private func startButton(_ unit: CurriculumUnit) -> some View {
        if started {
            Label("Bu bölümün kartları widget'ında", systemImage: "checkmark.circle.fill")
                .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Palette.greenInk)
        } else {
            Button("Bu bölüme başla") {
                Task {
                    let id = unit.id
                    await model.write(rebuildQueue: true) { db in try Curriculum.start(id, db: db) }
                    toast = "Kelimeler widget'ına geliyor"
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 50))
        }
    }

    private func storiesSection(_ unit: CurriculumUnit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                caption("HİKÂYELER")
                Spacer()
                if let random = unit.stories.randomElement() {
                    NavigationLink(value: Route.story(unit.id, random.id)) {
                        Label("Rastgele", systemImage: "shuffle")
                            .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(unit.stories.enumerated()), id: \.element.id) { index, story in
                    if index > 0 { Divider().overlay(Palette.line) }
                    NavigationLink(value: Route.story(unit.id, story.id)) {
                        HStack {
                            Text(story.title).font(KelimeFont.english(19, relativeTo: .body))
                            Spacer()
                            Text("\(story.lines.count) satır").font(KelimeFont.ui(12)).foregroundStyle(Palette.ink2)
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Palette.ink2)
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line))
        }
    }

    @ViewBuilder
    private func cardSection(_ title: String, _ cards: [Card]) -> some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                caption("\(title) (\(cards.count))")
                VStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        if index > 0 { Divider().overlay(Palette.line) }
                        NavigationLink(value: Route.word(card.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.word).font(KelimeFont.english(19, relativeTo: .body))
                                Text(card.meaning).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                            }
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line))
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
            .tracking(0.7)
            .foregroundStyle(Palette.ink2)
    }
}

/// A story to read: English lines, Turkish on demand, tap a line to hear it.
struct StoryView: View {
    @Environment(AppModel.self) private var model
    let unitID: String
    let storyID: String
    @State private var story: UnitStory?
    @State private var showTurkish = false

    var body: some View {
        ScrollView {
            if let story {
                VStack(alignment: .leading, spacing: 16) {
                    Text(story.title)
                        .font(KelimeFont.english(34, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(story.lines.enumerated()), id: \.offset) { _, line in
                        Button { Speaker.shared.speak(line.en) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.en)
                                    .font(KelimeFont.english(22, relativeTo: .title3))
                                    .foregroundStyle(Palette.ink)
                                if showTurkish {
                                    Text(line.tr)
                                        .font(KelimeFont.ui(15, relativeTo: .subheadline))
                                        .foregroundStyle(Palette.ink2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Dinlemek için dokun")
                    }
                    Text("Satıra dokun, dinle.")
                        .font(KelimeFont.ui(12, relativeTo: .caption))
                        .foregroundStyle(Palette.ink2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(showTurkish ? "Türkçesini gizle" : "Türkçesini göster") {
                withAnimation(.snappy) { showTurkish.toggle() }
            }
            .buttonStyle(TintedButtonStyle(ink: Palette.ink, background: Palette.surface2, height: 50))
            .padding(10)
            .floatingGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), fallback: Palette.background)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .task {
            let unitID = unitID, storyID = storyID
            story = await model.read { db in
                try CurriculumUnit.fetchOne(db, key: unitID)?.stories.first { $0.id == storyID }
            } ?? nil
        }
    }
}
