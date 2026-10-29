import KelimeCore
import KelimeUI
import SwiftUI
import TipKit

/// Teaches the swipe actions once; gone after the first swipe or when closed.
struct SwipeTip: Tip {
    var title: Text { Text("Satırı sola kaydır") }
    var message: Text? { Text("Biliyorum ya da Zorlanıyorum diye işaretle.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct WordsView: View {
    @Environment(AppModel.self) private var model
    @State private var showDecks = false
    @State private var segment: WordSegment = .struggling
    @State private var search = ""
    /// Tümü only; reset each launch.
    @State private var filter = WordFilter()
    @State private var showFilters = false
    /// Kept across launches.
    @AppStorage("words.sort") private var sort: WordSort = .alphabetical
    @State private var items: [WordItem] = []
    @State private var stats: WeekStats?
    @State private var decks: [DeckProgress] = []
    @State private var ownLists: [UserListSummary] = []
    @State private var course: CourseState?
    @State private var openRow: String?
    private let swipeTip = SwipeTip()

    var body: some View {
        // One page: title, controls and words scroll together on the same background.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header.padding(.horizontal, 20)
                    if showDecks {
                        lists
                    } else {
                        listControls.padding(.horizontal, 20)
                        wordList
                    }
                }
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .overlay(alignment: .trailing) {
                if showsIndex {
                    LetterIndex(items: items) { id in proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
        .screenBackground()
        .hiddenNavigationBar()
        .sheet(isPresented: $showFilters) {
            WordFilterSheet(filter: $filter)
                .presentationDetents([.medium, .large])
                .presentationBackground(Palette.background)
        }
        .task(id: model.router.listsRequested) {
            guard model.router.listsRequested else { return }
            showDecks = true
            model.router.listsRequested = false
        }
        .onChange(of: sort) { UsageCounter.count(.sort) }
        .onChange(of: showFilters) { _, shown in if shown { UsageCounter.count(.filter) } }
        .onChange(of: showDecks) { _, shown in if shown { UsageCounter.count(.units) } }
        .onChange(of: openRow) { _, row in
            if row != nil { swipeTip.invalidate(reason: .actionPerformed) }
        }
        .task(id: ReloadKey(version: model.dataVersion, segment: segment, search: search, decks: showDecks, filter: filter, sort: sort)) {
            await reload()
        }
    }

    /// Listeler: what the widget and reviews draw from. The course and the exam lists use the
    /// same card; the last list that is on cannot be switched off.
    @ViewBuilder
    private var lists: some View {
        // The course counts as one source: every level deck goes on and off with its card.
        let courseOn = decks.contains { $0.deck.level != nil && $0.enabled }
        let examsOn = decks.filter { $0.deck.tag != nil && $0.enabled }.count
        let listsOn = ownLists.filter { $0.list.enabled && $0.total > 0 }.count
        let onCount = course != nil ? (courseOn ? 1 : 0) + examsOn + listsOn : decks.filter(\.enabled).count + listsOn
        VStack(alignment: .leading, spacing: 18) {
            if let course {
                // The learner's own lists lead: they are what they come here for most often.
                caption("KENDİ LİSTELERİM")
                OwnListsSection(lists: ownLists, keepOn: { $0.list.enabled && $0.total > 0 && onCount == 1 })
                caption("KURS")
                if let deck = decks.first(where: { $0.deck.level == course.level }) {
                    DeckCard(deck: deck.with(enabled: courseOn), title: "\(course.level.rawValue) kursu", keepOn: courseOn && onCount == 1) { on in
                        Task { await model.setCourse(enabled: on) }
                    }
                }
                Text(courseOn ? "Kapatırsan widget'ta sadece açtığın sınav listeleri ve kendi listelerin döner." : "Kurs widget'ta kapalı; widget açtığın listelerden kelime gösteriyor.")
                    .font(KelimeFont.ui(12, relativeTo: .caption))
                    .foregroundStyle(Palette.ink2)
                UnitList(course: course)
                let exams = decks.filter { $0.deck.tag != nil }
                if !exams.isEmpty {
                    caption("SINAV LİSTELERİ")
                    DecksGrid(decks: exams, keepOn: { $0.enabled && onCount == 1 })
                }
            } else {
                DecksGrid(decks: decks, keepOn: { $0.enabled && onCount == 1 })
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
            .tracking(0.7)
            .foregroundStyle(Palette.ink2)
    }

    /// The letter strip, for long alphabetical lists (A–Z or Z–A).
    private var showsIndex: Bool {
        !showDecks && (sort == .alphabetical || sort == .reverseAlphabetical) && items.count > 40
    }

    @ViewBuilder
    private var wordList: some View {
        if items.isEmpty {
            emptyState.padding(.horizontal, 20)
        } else {
            TipView(swipeTip)
                .tipBackground(Palette.surface)
                .padding(.horizontal, 20)
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    SwipeRow(id: item.id, actions: actions(for: item), openRow: $openRow) {
                        model.router.openWord(item.id)
                    } content: {
                        WordRow(item: item)
                    }
                    .id(item.id)
                    Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 20)
                }
            }
            .animation(.snappy, value: items.map(\.id))
            .padding(.bottom, 24)
        }
    }

    /// The action that matches the word's current state is left out.
    private func actions(for item: WordItem) -> [SwipeRow<WordRow>.Action] {
        var actions: [SwipeRow<WordRow>.Action] = []
        if item.state != .learned {
            actions.append(.init(title: "Biliyorum", systemImage: "checkmark", ink: Palette.greenInk, background: Palette.greenBackground) {
                Task { await model.record(.markedKnown, cardID: item.id, source: .wordDetail) }
            })
        }
        if item.state != .struggling {
            actions.append(.init(title: "Zorlanıyorum", systemImage: "arrow.uturn.backward", ink: Palette.amberInk, background: Palette.amberBackground) {
                Task { await model.record(.markedStruggling, cardID: item.id, source: .wordDetail) }
            })
        }
        return actions
    }

    private struct ReloadKey: Equatable {
        var version: Int
        var segment: WordSegment
        var search: String
        var decks: Bool
        var filter: WordFilter
        var sort: WordSort
    }

    private func reload() async {
        let clock = model.clock
        course = await model.read { db in try Curriculum.state(db: db) } ?? nil
        if showDecks {
            decks = await model.read { db in try DeckQueries.progress(db: db) } ?? []
            ownLists = await model.read { db in try UserLists.summaries(db: db) } ?? []
        } else {
            let segment = segment, search = search, sort = sort
            let filter = segment == .all ? filter : WordFilter()
            items = await model.read { db in try WordQueries.list(segment: segment, search: search, filter: filter, sort: sort, db: db) } ?? []
            stats = await model.read { db in try StatsQueries.week(db: db, clock: clock) }
        }
    }

    /// The title, then a two-way switch between the words and the lists.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScreenTitle(title: "Kelimelerim")
            SegmentedPicker(options: [false, true], selection: Binding(
                get: { showDecks },
                set: { value in withAnimation(.snappy) { showDecks = value } }
            )) { $0 ? "Listeler" : "Kelimeler" }
        }
    }

    private var listControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let stats {
                (Text("Bu hafta ") + Text("\(stats.learnedThisWeek) öğrenildi").bold().foregroundStyle(Palette.greenInk)
                    + Text(" · şu an ") + Text("\(stats.strugglingNow) zorlanılan").bold().foregroundStyle(Palette.amberInk))
                    .font(KelimeFont.ui(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
            }
            HStack(spacing: 8) {
                TextField("Kelime ya da anlam ara", text: $search)
                    .font(KelimeFont.ui(16, relativeTo: .body))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Menu {
                    Picker("Sırala", selection: $sort) {
                        ForEach(WordSort.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } label: {
                    controlIcon("arrow.up.arrow.down")
                }
                .accessibilityLabel("Sırala: \(sort.label)")
                if segment == .all {
                    Button { showFilters = true } label: {
                        controlIcon("line.3.horizontal.decrease", active: !filter.isEmpty)
                    }
                    .accessibilityLabel(filter.isEmpty ? "Filtrele" : "Filtrele, \(filter.count) filtre açık")
                }
            }
            SegmentedPicker(options: WordSegment.allCases, selection: $segment) { $0.label }
            if segment == .all && !filter.isEmpty {
                ActiveFilters(filter: $filter)
            }
        }
    }

    private func controlIcon(_ name: String, active: Bool = false) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(active ? Palette.onAccent : Palette.ink)
            .frame(width: 44, height: 44)
            .background(active ? Palette.accent : Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Circle().strokeBorder(Palette.ink2, lineWidth: 1.5).frame(width: 14, height: 14)
            Text(search.isEmpty && (segment != .all || filter.isEmpty) ? segment.emptyText : WordSegment.all.emptyText)
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            if search.isEmpty && segment != .favorites {
                Button("Hızlı Tekrar") { Task { await model.startQuickReview() } }
                    .buttonStyle(PrimaryButtonStyle(height: 44))
                    .frame(maxWidth: 180)
            }
        }
        // Plain text on the page background, centred: an empty list needs no card.
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

struct WordRow: View {
    let item: WordItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.card.word).font(KelimeFont.english(22, relativeTo: .title3))
                Text(item.card.meaning)
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StateChip(item.state)
            LevelChip(item.card.level)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 20)
        .frame(minHeight: 66)
        .background(Palette.background)
    }
}

struct DecksGrid: View {
    @Environment(AppModel.self) private var model
    let decks: [DeckProgress]
    var keepOn: (DeckProgress) -> Bool = { _ in false }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(decks) { deck in
                DeckCard(deck: deck, keepOn: keepOn(deck))
            }
        }
    }
}

struct DeckCard: View {
    @Environment(AppModel.self) private var model
    let deck: DeckProgress
    var title: String?
    /// The only list that is on: switching it off would leave the widget empty.
    var keepOn = false
    /// Replaces the deck switch (the course card turns every level deck at once).
    var onToggle: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title ?? deck.deck.rawValue).font(KelimeFont.english(24, relativeTo: .title2))
            Text(deck.isFinished ? "Bu listeyi bitirdin 🎉" : countText)
                .font(KelimeFont.ui(12, relativeTo: .caption))
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
            ThinProgressBar(fraction: deck.fraction)
            Toggle(isOn: Binding(
                get: { deck.enabled },
                set: { value in
                    if let onToggle { onToggle(value) } else { Task { await model.setDeck(deck.deck, enabled: value) } }
                }
            )) {
                Text("Widget'ta").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            }
            .tint(Palette.green)
            .disabled(deck.total == 0 || keepOn)
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 18, padding: 14)
        .accessibilityElement(children: .contain)
    }

    private var countText: String {
        deck.total == 0 ? "Yakında" : "\(deck.learned) / \(deck.total) kelime öğrenildi"
    }
}
