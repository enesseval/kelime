import KelimeCore
import KelimeUI
import SwiftUI

struct WordsView: View {
    @Environment(AppModel.self) private var model
    @State private var showDecks = false
    @State private var segment: WordSegment = .struggling
    @State private var search = ""
    @State private var items: [WordItem] = []
    @State private var stats: WeekStats?
    @State private var decks: [DeckProgress] = []
    @State private var openRow: String?

    var body: some View {
        // One page: title, controls and words scroll together on the same background.
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header.padding(.horizontal, 20)
                if showDecks {
                    DecksGrid(decks: decks)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                } else {
                    listControls.padding(.horizontal, 20)
                    wordList
                }
            }
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .hiddenNavigationBar()
        .task(id: ReloadKey(version: model.dataVersion, segment: segment, search: search, decks: showDecks)) {
            await reload()
        }
    }

    @ViewBuilder
    private var wordList: some View {
        if items.isEmpty {
            emptyState.padding(.horizontal, 20)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    SwipeRow(id: item.id, actions: actions(for: item), openRow: $openRow) {
                        model.router.openWord(item.id)
                    } content: {
                        WordRow(item: item)
                    }
                    Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 20)
                }
            }
            .animation(.snappy, value: items.map(\.id))
            Text("Satırı sola kaydır: Biliyorum · Zorlanıyorum")
                .font(KelimeFont.ui(12, relativeTo: .caption))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
    }

    /// The action that matches the word's current state is left out.
    private func actions(for item: WordItem) -> [SwipeRow<WordRow>.Action] {
        var actions: [SwipeRow<WordRow>.Action] = []
        if item.state != .learned {
            actions.append(.init(title: "Biliyorum", systemImage: "checkmark", color: Palette.green) {
                Task { await model.record(.markedKnown, cardID: item.id, source: .wordDetail) }
            })
        }
        if item.state != .struggling {
            actions.append(.init(title: "Zorlanıyorum", systemImage: "arrow.uturn.backward", color: Palette.amber) {
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
    }

    private func reload() async {
        let clock = model.clock
        if showDecks {
            decks = await model.read { db in try DeckQueries.progress(db: db) } ?? []
        } else {
            let segment = segment, search = search
            items = await model.read { db in try WordQueries.list(segment: segment, search: search, db: db) } ?? []
            stats = await model.read { db in try StatsQueries.week(db: db, clock: clock) }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            ScreenTitle(title: "Kelimelerim")
            Spacer()
            Button(showDecks ? "Kelimeler" : "Desteler") {
                withAnimation(.snappy) { showDecks.toggle() }
            }
            .buttonStyle(TintedButtonStyle(fullWidth: false))
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
            TextField("Kelime ya da anlam ara", text: $search)
                .font(KelimeFont.ui(16, relativeTo: .body))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            SegmentedPicker(options: WordSegment.allCases, selection: $segment) { $0.label }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Circle().strokeBorder(Palette.ink2, lineWidth: 1.5).frame(width: 14, height: 14)
            Text(search.isEmpty ? segment.emptyText : WordSegment.all.emptyText)
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            if search.isEmpty && segment != .favorites {
                Button("Hızlı Tekrar") { Task { await model.startQuickReview() } }
                    .buttonStyle(PrimaryButtonStyle(height: 44))
                    .frame(maxWidth: 180)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .surfaceCard(radius: 18, padding: 0)
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

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(decks) { deck in
                DeckCard(deck: deck)
            }
        }
    }
}

struct DeckCard: View {
    @Environment(AppModel.self) private var model
    let deck: DeckProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(deck.deck.rawValue).font(KelimeFont.english(24, relativeTo: .title2))
                Spacer()
                if deck.locked {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Palette.ink2)
                        .accessibilityLabel("Pro")
                }
            }
            Text(deck.isFinished ? "Bu desteyi bitirdin 🎉" : countText)
                .font(KelimeFont.ui(12, relativeTo: .caption))
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
            ThinProgressBar(fraction: deck.fraction)
            if deck.locked {
                HStack {
                    Text("Widget'ta").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                    Spacer()
                    ProBadge()
                }
                .frame(minHeight: 31)
            } else {
                Toggle(isOn: Binding(
                    get: { deck.enabled },
                    set: { value in Task { await model.setDeck(deck.deck, enabled: value) } }
                )) {
                    Text("Widget'ta").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                }
                .tint(Palette.green)
                .disabled(deck.total == 0)
            }
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 18, padding: 14)
        .opacity(deck.locked ? 0.7 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if deck.locked { model.router.showPaywall(.proDeck, deck: deck.deck) }
        }
        .accessibilityElement(children: .contain)
    }

    private var countText: String {
        deck.total == 0 ? "Yakında" : "\(deck.learned) / \(deck.total) kelime öğrenildi"
    }
}
