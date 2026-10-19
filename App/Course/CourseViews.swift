import KelimeCore
import KelimeUI
import SwiftUI

/// Bugün's "Şu anki bölüm": the unit the learner is on, a story near its end, and the way on
/// to the next level once this one is done.
struct CurrentUnitCard: View {
    @Environment(AppModel.self) private var model
    let course: CourseState

    var body: some View {
        if let current = course.current {
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink(value: Route.unit(current.id)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ŞU ANKİ BÖLÜM")
                                .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                                .tracking(0.7)
                                .foregroundStyle(Palette.ink2)
                            Spacer()
                            Text("\(course.level.rawValue) · \(position(of: current))/\(course.units.count)")
                                .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
                                .foregroundStyle(Palette.ink2)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(current.unit.title).font(KelimeFont.english(28, relativeTo: .title))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                        }
                        Text(current.unit.goal)
                            .font(KelimeFont.ui(14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        ThinProgressBar(fraction: current.fraction).padding(.top, 2)
                        Text("\(current.learned)/\(current.total) kart öğrenildi")
                            .font(KelimeFont.ui(12, relativeTo: .caption))
                            .foregroundStyle(Palette.ink2)
                    }
                    .foregroundStyle(Palette.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Near the end of the unit the words are known well enough to read a story.
                if current.fraction >= 0.5, !current.unit.stories.isEmpty {
                    let story = current.unit.stories[current.learned % current.unit.stories.count]
                    NavigationLink(value: Route.story(current.id, story.id)) {
                        Label("Hikâye oku: \(story.title)", systemImage: "book")
                            .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                    }
                    .buttonStyle(TintedButtonStyle(height: 44))
                }
                if let next = course.nextLevel {
                    Button("\(next.rawValue) seviyesine geç") {
                        Task { await model.write(rebuildQueue: true) { db in try Curriculum.moveOn(to: next, db: db) } }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 48))
                }
            }
            .surfaceCard(padding: 20)
        } else if course.isComplete {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(course.level.rawValue) bitti 🎉").font(KelimeFont.english(28, relativeTo: .title))
                Text(course.nextLevel.map { "\($0.rawValue) bölümleri hazır." } ?? "Sonraki seviyenin bölümleri hazırlanıyor. Zorlandığın kartlar widget'ında kalır.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                if let next = course.nextLevel {
                    Button("\(next.rawValue) seviyesine geç") {
                        Task { await model.write(rebuildQueue: true) { db in try Curriculum.moveOn(to: next, db: db) } }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 48))
                    .padding(.top, 6)
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(padding: 20)
        }
    }

    private func position(of unit: UnitProgress) -> Int {
        (course.units.firstIndex { $0.id == unit.id } ?? 0) + 1
    }
}

/// Kelimelerim's "Bölümler": the level's units in the learner's order.
struct UnitList: View {
    let course: CourseState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bölümler sırayla açılır; biri bitmeye yakınken sıradaki başlar. İstersen başka bir bölüme geçebilirsin.")
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
            ForEach(course.units) { item in
                NavigationLink(value: Route.unit(item.unit.id)) { row(item) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func row(_ item: UnitProgress) -> some View {
        let isCurrent = item.id == course.currentID
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.unit.title).font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                Spacer()
                status(item, isCurrent: isCurrent)
            }
            Text(item.unit.goal)
                .font(KelimeFont.ui(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if item.started {
                ThinProgressBar(fraction: item.fraction).padding(.top, 2)
            }
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 18, padding: 16)
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.accent, lineWidth: 1.5)
            }
        }
    }

    @ViewBuilder
    private func status(_ item: UnitProgress, isCurrent: Bool) -> some View {
        if item.isFinished {
            Text("Bitti ✓").font(KelimeFont.ui(12, weight: .semibold)).foregroundStyle(Palette.greenInk)
        } else if isCurrent {
            Text("Şu an · \(item.learned)/\(item.total)").font(KelimeFont.ui(12, weight: .semibold)).foregroundStyle(Palette.accent)
        } else if item.started {
            Text("\(item.learned)/\(item.total)").font(KelimeFont.ui(12, weight: .semibold)).foregroundStyle(Palette.ink2)
        } else {
            Text("\(item.total) kart").font(KelimeFont.ui(12)).foregroundStyle(Palette.ink2)
        }
    }
}

/// One unit: its goal, the start button, stories, phrases and words.
struct UnitView: View {
    @Environment(AppModel.self) private var model
    let unitID: String
    @State private var unit: CurriculumUnit?
    @State private var cards: [Card] = []
    @State private var isCurrent = false
    @State private var finished = false
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
            let loaded = await model.read { db -> (CurriculumUnit?, [Card], UnitProgress?, String?) in
                let unit = try CurriculumUnit.fetchOne(db, key: id)
                let progress = try unit.flatMap { u in try Curriculum.progress(level: u.level, db: db).first { $0.id == id } }
                return (unit, try Curriculum.cards(of: id, db: db), progress, try Curriculum.state(db: db)?.currentID)
            }
            unit = loaded?.0
            cards = loaded?.1 ?? []
            finished = loaded?.2?.isFinished ?? false
            isCurrent = loaded?.3 == id
        }
        .toast($toast)
    }

    @ViewBuilder
    private func startButton(_ unit: CurriculumUnit) -> some View {
        if finished {
            Label("Bu bölümü bitirdin", systemImage: "checkmark.circle.fill")
                .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Palette.greenInk)
        } else if isCurrent {
            Label("Şu an bu bölümdesin, kartları widget'ında", systemImage: "checkmark.circle.fill")
                .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Palette.greenInk)
        } else {
            Button("Bu bölüme geç") {
                Task {
                    let id = unit.id
                    await model.write(rebuildQueue: true) { db in try Curriculum.makeCurrent(id, db: db) }
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
