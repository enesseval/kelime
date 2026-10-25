import KelimeCore
import KelimeUI
import SwiftUI

/// Keşfet: lists other learners made public. Browsing needs no account.
struct DiscoverView: View {
    @Environment(AppModel.self) private var app
    @State private var search = ""
    @State private var sort: AccountManager.DiscoverSort = .popular
    @State private var items: [AccountManager.DiscoverItem] = []
    @State private var loading = false
    @State private var failed = false
    @State private var page = 0
    @State private var hasMore = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Keşfet")
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.ink2)
                    TextField("Liste ara", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                }
                .font(KelimeFont.ui(15, relativeTo: .body))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                SegmentedPicker(options: AccountManager.DiscoverSort.allCases, selection: $sort) { $0 == .popular ? "Popüler" : "Yeni" }

                if items.isEmpty && !loading {
                    VStack(spacing: 8) {
                        Image(systemName: failed ? "wifi.slash" : "sparkle.magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundStyle(Palette.ink2)
                        Text(failed ? "Keşfet'e ulaşılamadı" : (search.isEmpty ? "Henüz herkese açık liste yok" : "Bu aramayla liste bulunamadı"))
                            .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                        Text(failed ? "İnternet bağlantını kontrol edip tekrar dene." : "Kendi listeni Kelimelerim › Listeler'den herkese açabilirsin.")
                            .font(KelimeFont.ui(13, relativeTo: .footnote))
                            .foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.center)
                        if failed {
                            Button("Tekrar dene") { Task { await load(reset: true) } }
                                .buttonStyle(TintedButtonStyle(fullWidth: false))
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: Route.sharedList(item.id)) { DiscoverRow(item: item) }
                            .buttonStyle(.plain)
                            .onAppear {
                                if item == items.last, hasMore { Task { await load(reset: false) } }
                            }
                    }
                }
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .hiddenNavigationBar()
        .refreshable { await load(reset: true) }
        .task(id: "\(search)|\(sort.rawValue)") {
            try? await Task.sleep(for: .milliseconds(search.isEmpty ? 0 : 300))
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
    }

    private func load(reset: Bool) async {
        if reset {
            page = 0
            hasMore = true
        }
        guard hasMore, !loading || reset else { return }
        loading = true
        defer { loading = false }
        do {
            let next = try await app.account.discover(search: search.trimmingCharacters(in: .whitespaces), sort: sort, page: page)
            items = reset ? next : items + next.filter { new in !items.contains { $0.id == new.id } }
            hasMore = next.count == 30
            page += 1
            failed = false
        } catch {
            if reset { items = [] }
            failed = !(error is CancellationError)
        }
    }
}

struct DiscoverRow: View {
    let item: AccountManager.DiscoverItem

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatar: item.avatar, name: item.ownerName, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(KelimeFont.english(21, relativeTo: .title3)).lineLimit(1)
                Text("\(item.ownerName) · \(item.word_count) kelime" + (item.saves > 0 ? " · \(item.saves) kayıt" : ""))
                    .font(KelimeFont.ui(12, relativeTo: .caption))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink2)
        }
        .foregroundStyle(Palette.ink)
        .surfaceCard(radius: 18, padding: 14)
    }
}

/// A list from Keşfet or a link: its words, "Listelerime ekle", report and block.
struct SharedListView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State private var item: AccountManager.SharedItem?
    @State private var state: LoadState = .loading
    @State private var savedID: String?
    @State private var toast: String?
    @State private var reporting = false
    @State private var confirmBlock = false

    enum LoadState { case loading, ready, missing, failed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                case .missing, .failed:
                    VStack(spacing: 8) {
                        Image(systemName: state == .missing ? "lock" : "wifi.slash").font(.system(size: 30)).foregroundStyle(Palette.ink2)
                        Text(state == .missing ? "Bu liste paylaşılmıyor" : "Liste açılamadı")
                            .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                        Text(state == .missing ? "Sahibi listeyi gizlemiş ya da silmiş olabilir." : "İnternet bağlantını kontrol edip tekrar dene.")
                            .font(KelimeFont.ui(13, relativeTo: .footnote))
                            .foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                case .ready:
                    if let item { content(item) }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .toolbar {
            if let item, item.owner != app.account.userID {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Şikayet et", systemImage: "flag") { requireAccount { reporting = true } }
                        Button("Kullanıcıyı engelle", systemImage: "hand.raised") { requireAccount { confirmBlock = true } }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Liste seçenekleri")
                }
            }
        }
        .confirmationDialog("Neden şikayet ediyorsun?", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(["Uygunsuz ya da saldırgan içerik", "Spam ya da reklam", "Yanlış ya da yanıltıcı içerik", "Başka bir sebep"], id: \.self) { reason in
                Button(reason) { Task { await report(reason) } }
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog("Kullanıcı engellensin mi?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Engelle", role: .destructive) { Task { await block() } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu kişinin listeleri artık Keşfet'te sana görünmez.")
        }
        .toast($toast)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ item: AccountManager.SharedItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(KelimeFont.english(34, relativeTo: .largeTitle))
                .tracking(-0.6)
            HStack(spacing: 8) {
                AvatarView(avatar: item.avatar, name: item.ownerName, size: 26)
                Text("\(item.ownerName) · \(item.cards.count) kelime" + (item.saves > 0 ? " · \(item.saves) kayıt" : ""))
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
            }
            if item.owner == app.account.userID {
                Text("Bu senin listen.")
                    .font(KelimeFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 4)
            } else if let savedID {
                Button { open(savedID) } label: {
                    Label("Listelerinde · aç", systemImage: "checkmark")
                }
                .buttonStyle(TintedButtonStyle(ink: Palette.greenInk, background: Palette.greenBackground, height: 50))
                .padding(.top, 4)
            } else {
                Button { Task { await save(item) } } label: {
                    Label("Listelerime ekle", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle(height: 50))
                .padding(.top, 4)
                Text("Liste widget'ına ve Hızlı Tekrar'a eklenir. Bildiğin kelimeler ilerlemeni korur.")
                    .font(KelimeFont.ui(12, relativeTo: .caption))
                    .foregroundStyle(Palette.ink2)
            }
        }
        .padding(.horizontal, 20)
        LazyVStack(spacing: 0) {
            ForEach(item.cards) { card in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.word).font(KelimeFont.english(20, relativeTo: .body)).foregroundStyle(Palette.ink)
                        Text(card.meaning).font(KelimeFont.ui(13, relativeTo: .footnote)).foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    if !card.id.hasPrefix(UserLists.customPrefix) { LevelChip(card.level) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 20)
            }
        }
    }

    private func load() async {
        do {
            item = try await app.account.sharedList(listID)
            state = item == nil ? .missing : .ready
            let id = listID
            savedID = await app.read { db in try UserLists.savedCopy(of: id, db: db)?.id } ?? nil
        } catch {
            state = .failed
        }
    }

    private func save(_ item: AccountManager.SharedItem) async {
        let shared = SharedList(title: item.title, cards: item.cards)
        guard let newID = await app.importShared(shared, sourceID: listID) else {
            toast = "Liste eklenemedi"
            return
        }
        savedID = newID
        toast = "\(item.title) listelerine eklendi"
        await app.account.recordSave(listID)
    }

    private func open(_ id: String) {
        app.router.openLists()
        app.router.wordsPath = [.userList(id)]
    }

    private func requireAccount(_ action: () -> Void) {
        if app.account.isSignedIn {
            action()
        } else {
            toast = "Bunun için Profil'den giriş yap"
        }
    }

    private func report(_ reason: String) async {
        toast = await app.account.report(listID, reason: reason) ? "Teşekkürler, inceleyeceğiz" : "Şikayet gönderilemedi"
    }

    private func block() async {
        guard let owner = item?.owner else { return }
        if await app.account.block(owner) {
            toast = "Engellendi"
            dismiss()
        } else {
            toast = "Engellenemedi"
        }
    }
}

/// Kelimelerim › liste › Paylaşım: who may open the list, and its link.
struct VisibilitySheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let list: UserList
    @State private var visibility: ListVisibility = .private
    @State private var shareLink: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ListVisibility.allCases, id: \.self) { option in
                        Button { Task { await choose(option) } } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option.symbol).frame(width: 26).foregroundStyle(Palette.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label).foregroundStyle(Palette.ink)
                                    Text(option.detail).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.ink2)
                                }
                                Spacer()
                                if visibility == option { Image(systemName: "checkmark").foregroundStyle(Palette.accent).fontWeight(.semibold) }
                                else if option != .private && !app.isPro { ProBadge() }
                            }
                        }
                    }
                } footer: {
                    Text("Liste hesabınla eşitlenir; değişikliklerin paylaştığın herkeste güncellenir.")
                }
                if visibility != .private {
                    Section {
                        Button {
                            shareLink = AccountManager.link(for: list.id)
                            UsageCounter.count(.listShared)
                        } label: {
                            Label("Linki paylaş", systemImage: "link")
                        }
                    }
                }
            }
            .navigationTitle("Paylaşım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { dismiss() }.fontWeight(.semibold) }
            }
            .sheet(item: $shareLink) { url in
                ShareSheet(items: [list.title, url]).presentationDetents([.medium, .large])
            }
            .onAppear { visibility = list.visibility }
        }
    }

    private func choose(_ option: ListVisibility) async {
        if option != .private && !app.isPro {
            dismiss()
            app.router.showPaywall(.share)
            return
        }
        visibility = option
        let id = list.id
        try? await app.editList { db in try UserLists.setVisibility(option, list: id, db: db) }
    }
}

extension ListVisibility {
    var label: String {
        switch self {
        case .private: "Sadece ben"
        case .link: "Linke sahip olanlar"
        case .public: "Herkese açık"
        }
    }

    var detail: String {
        switch self {
        case .private: "Liste sadece senin cihazlarında görünür."
        case .link: "Linki gönderdiğin kişiler açıp ekleyebilir."
        case .public: "Keşfet'te herkes görür ve ekleyebilir."
        }
    }

    var symbol: String {
        switch self {
        case .private: "lock"
        case .link: "link"
        case .public: "globe"
        }
    }
}
