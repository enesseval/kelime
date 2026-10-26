import KelimeCore
import KelimeUI
import SwiftUI

/// Listeler › KENDİ LİSTELERİM: the learner's lists, each with a "Widget'ta" switch, and a
/// button for a new one (free users get one; the second asks for Pro).
struct OwnListsSection: View {
    @Environment(AppModel.self) private var model
    let lists: [UserListSummary]
    /// The only source that is on: switching it off would leave the widget empty.
    let keepOn: (UserListSummary) -> Bool
    @State private var naming = false
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lists) { summary in
                NavigationLink(value: Route.userList(summary.id)) {
                    UserListCard(summary: summary, keepOn: keepOn(summary))
                }
                .buttonStyle(.plain)
            }
            Button {
                title = ""
                naming = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text(lists.isEmpty ? "İlk listeni oluştur" : "Yeni liste")
                    Spacer()
                    if !model.isPro && !lists.filter({ !$0.list.imported }).isEmpty { ProBadge() }
                }
                .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if lists.isEmpty {
                Text("Kendi kelimelerini topla; widget'ta kursla birlikte dönsün.")
                    .font(KelimeFont.ui(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
            }
        }
        .alert("Yeni liste", isPresented: $naming) {
            TextField("Örn. İş toplantısı", text: $title)
            Button("Vazgeç", role: .cancel) {}
            Button("Oluştur") {
                Task {
                    if let list = await model.createList(title: title) {
                        model.router.wordsPath.append(.userList(list.id))
                    }
                }
            }
        }
    }
}

struct UserListCard: View {
    @Environment(AppModel.self) private var model
    let summary: UserListSummary
    var keepOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.list.title).font(KelimeFont.english(22, relativeTo: .title3)).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink2)
            }
            Text(summary.total == 0 ? "Henüz kelime yok" : "\(summary.learned) / \(summary.total) kelime öğrenildi")
                .font(KelimeFont.ui(12, relativeTo: .caption))
                .foregroundStyle(Palette.ink2)
            ThinProgressBar(fraction: summary.fraction)
            Toggle(isOn: Binding(
                get: { summary.list.enabled },
                set: { on in Task { try? await model.editList { db in try UserLists.setEnabled(on, list: summary.id, db: db) } } }
            )) {
                Text("Widget'ta").font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
            }
            .tint(Palette.green)
            .disabled(summary.total == 0 || keepOn)
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 18, padding: 14)
    }
}

/// One list: its words, adding and removing them, renaming, sharing and deleting.
struct UserListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State private var list: UserList?
    @State private var cards: [WordItem] = []
    @State private var adding = false
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false
    @State private var shareURL: URL?
    @State private var visibilityList: UserList?
    /// The row whose swipe actions are showing.
    @State private var openRow: String?
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let list {
                    Text(list.title)
                        .font(KelimeFont.english(34, relativeTo: .largeTitle))
                        .tracking(-0.6)
                        .padding(.horizontal, 20)
                    Text(cards.isEmpty ? "Kelime ekle; listeyi açınca widget'ta ve Hızlı Tekrar'da görünür." : "\(cards.count) kelime" + (list.enabled ? " · widget'ta" : ""))
                        .font(KelimeFont.ui(14, relativeTo: .subheadline))
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 20)
                    Button { adding = true } label: {
                        Label("Kelime ekle", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 50))
                    .padding(.horizontal, 20)
                    LazyVStack(spacing: 0) {
                        ForEach(cards) { item in
                            SwipeRow(id: item.id, actions: [
                                SwipeRow.Action(title: "Listeden çıkar", systemImage: "trash", ink: .white, background: Palette.amberInk) { remove(item) },
                            ], openRow: $openRow) {
                                model.router.openWord(item.id)
                            } content: {
                                WordRow(item: item)
                            }
                            Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 20)
                        }
                    }
                    if !cards.isEmpty {
                        Text("Bir kelimeyi listeden çıkarmak için sola kaydır.")
                            .font(KelimeFont.ui(12, relativeTo: .caption))
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 24)
                    }
                }
            }
            .padding(.top, 6)
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let list, !list.imported {
                        Button("Paylaşım: \(list.visibility.label)", systemImage: list.visibility.symbol) { openVisibility(list) }
                    }
                    Button("Dosya olarak gönder", systemImage: "square.and.arrow.up") { Task { await share() } }
                        .disabled(cards.isEmpty)
                    Button("Adını değiştir", systemImage: "pencil") {
                        newTitle = list?.title ?? ""
                        renaming = true
                    }
                    Button("Listeyi sil", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Liste seçenekleri")
            }
        }
        .sheet(isPresented: $adding) {
            AddWordSheet(listID: listID).environment(model)
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(url: url).presentationDetents([.medium, .large])
        }
        .sheet(item: $visibilityList) { list in
            VisibilitySheet(list: list).environment(model).presentationDetents([.medium, .large])
        }
        .toast($toast)
        .alert("Listenin adı", isPresented: $renaming) {
            TextField("Ad", text: $newTitle)
            Button("Vazgeç", role: .cancel) {}
            Button("Kaydet") {
                let title = newTitle
                Task { try? await model.editList { db in try UserLists.rename(listID, to: title, db: db) } }
            }
        }
        .confirmationDialog("Liste silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                Task {
                    try? await model.editList { db in try UserLists.delete(listID, db: db) }
                    dismiss()
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Kendi yazdığın kelimeler de silinir. Uygulamanın kelimeleri ve ilerlemen yerinde kalır.")
        }
        .task(id: model.dataVersion) { await reload() }
    }

    private func reload() async {
        let id = listID
        list = await model.read { db in try UserLists.list(id: id, db: db) } ?? nil
        cards = await model.read { db in
            try UserLists.cards(of: id, db: db).compactMap { try WordQueries.item(id: $0.id, db: db) }
        } ?? []
    }

    private func remove(_ item: WordItem) {
        let id = listID, card = item.id
        Task { try? await model.editList { db in try UserLists.remove(cardID: card, from: id, db: db) } }
    }

    /// Link and Keşfet sharing go through the account.
    private func openVisibility(_ list: UserList) {
        guard model.account.isSignedIn else {
            toast = "Paylaşmak için Profil'den Apple ile giriş yap"
            return
        }
        visibilityList = list
    }

    /// Sharing is Pro; the file opens in the app on any phone that has it.
    private func share() async {
        guard model.isPro else {
            model.router.showPaywall(.share)
            return
        }
        shareURL = await model.exportList(listID)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// The system share sheet for a file or a link.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    init(url: URL) { items = [url] }
    init(items: [Any]) { self.items = items }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Adds words to a list: search the app's words (meaning and example come with them), or write
/// your own word.
struct AddWordSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State private var search = ""
    @State private var results: [Card] = []
    @State private var inList = Set<String>()
    @State private var writing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Kelime ya da anlam ara", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if !results.isEmpty {
                    Section("Uygulamadaki kelimeler") {
                        ForEach(results) { card in
                            Button { add(card) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.word).font(KelimeFont.english(19, relativeTo: .body)).foregroundStyle(Palette.ink)
                                        Text(card.meaning).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                                    }
                                    Spacer()
                                    LevelChip(card.level)
                                    Image(systemName: inList.contains(card.id) ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(inList.contains(card.id) ? Palette.green : Palette.accent)
                                        .font(.system(size: 20))
                                }
                            }
                            .disabled(inList.contains(card.id))
                        }
                    }
                }
                Section {
                    Button {
                        writing = true
                    } label: {
                        Label(search.isEmpty ? "Kendi kelimeni yaz" : "“\(search)” kelimesini kendin ekle", systemImage: "square.and.pencil")
                    }
                } footer: {
                    Text("Uygulamada olmayan bir kelimeyi anlamıyla birlikte ekleyebilirsin.")
                }
            }
            .navigationTitle("Kelime ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { dismiss() }.fontWeight(.semibold) }
            }
            .sheet(isPresented: $writing) {
                CustomWordForm(listID: listID, word: search) { dismiss() }.environment(model)
            }
            .toast($message)
            .task(id: search) {
                try? await Task.sleep(for: .milliseconds(200))
                let query = search, id = listID
                results = await model.read { db in try UserLists.suggestions(query, db: db) } ?? []
                inList = Set(await model.read { db in try UserLists.cards(of: id, db: db).map(\.id) } ?? [])
            }
        }
    }

    private func add(_ card: Card) {
        let id = listID
        Task {
            do {
                try await model.editList { db in try UserLists.add(cardID: card.id, to: id, db: db) }
                inList.insert(card.id)
                message = "\(card.word) eklendi"
            } catch {
                message = "Bu kelime listede var"
            }
        }
    }
}

/// The learner's own word: word and meaning are required, an example is optional.
struct CustomWordForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State var word: String
    let onAdded: () -> Void
    @State private var meaning = ""
    @State private var kind: PartOfSpeech = .noun
    @State private var exampleEN = ""
    @State private var exampleTR = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kelime (İngilizce)", text: $word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Anlamı (Türkçe; birden çoksa virgülle)", text: $meaning)
                    Picker("Türü", selection: $kind) {
                        Text("İsim").tag(PartOfSpeech.noun)
                        Text("Fiil").tag(PartOfSpeech.verb)
                        Text("Sıfat").tag(PartOfSpeech.adjective)
                        Text("Zarf").tag(PartOfSpeech.adverb)
                        Text("Kalıp").tag(PartOfSpeech.phrase)
                    }
                }
                Section {
                    TextField("Örnek cümle (İngilizce)", text: $exampleEN, axis: .vertical)
                    TextField("Örneğin Türkçesi", text: $exampleTR, axis: .vertical)
                } header: {
                    Text("İsteğe bağlı")
                }
                if let error {
                    Text(error).foregroundStyle(Palette.amberInk)
                }
            }
            .navigationTitle("Kendi kelimen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ekle") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty || meaning.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let id = listID, word = word, meaning = meaning, kind = kind, en = exampleEN, tr = exampleTR
        do {
            try await model.editList { db in
                let level = try Preferences.load(db).level
                try UserLists.addCustom(word: word, meaning: meaning, pos: kind, exampleEN: en, exampleTR: tr, level: level, to: id, db: db)
            }
            dismiss()
            onAdded()
        } catch UserListError.duplicateWord {
            error = "Bu kelime listede var."
        } catch {
            self.error = "Kelime ve anlam gerekli."
        }
    }
}
