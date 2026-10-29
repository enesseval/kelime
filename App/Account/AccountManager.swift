import AuthenticationServices
import CryptoKit
import Foundation
import KelimeCore
import Observation
import RevenueCat
import Supabase

/// The optional account: Sign in with Apple through Supabase, the profile (username, name,
/// avatar), two-way sync of own lists, and the Keşfet calls. Everything else in the app works
/// without it.
@MainActor
@Observable
final class AccountManager {
    static let url = URL(string: "https://elqtyiuvalanlsxuawar.supabase.co")!
    /// Publishable key: safe in the app, row level security guards the data.
    static let key = "sb_publishable_kxWgxMCrFmSfJqpxwZOVww_gf_eyWBa"
    /// A list link: opens the app, or the web page offering it.
    static func link(for listID: String) -> URL {
        URL(string: "https://enesseval.github.io/kelime/liste.html?id=\(listID)")!
    }

    let client = SupabaseClient(
        supabaseURL: AccountManager.url,
        supabaseKey: AccountManager.key,
        options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
    )

    private(set) var userID: UUID?
    private(set) var profile: Profile?
    private(set) var syncing = false
    private(set) var lastSync: Date?
    private(set) var lastError: String?

    var isSignedIn: Bool { userID != nil }

    private weak var app: AppModel?
    private var authTask: Task<Void, Never>?
    /// The nonce of the Apple request in flight; Supabase checks its hash in the token.
    private var nonce: String?

    func start(app: AppModel) {
        self.app = app
        guard authTask == nil else { return }
        authTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in client.auth.authStateChanges {
                let id = (session?.isExpired == false || event == .signedIn || event == .tokenRefreshed) ? session?.user.id : nil
                await self.sessionChanged(id)
            }
        }
    }

    private func sessionChanged(_ id: UUID?) async {
        guard id != userID else { return }
        userID = id
        if let id {
            _ = try? await Purchases.shared.logIn(id.uuidString.lowercased())
            await loadProfile()
            await sync()
        } else {
            profile = nil
        }
    }

    // MARK: - Sign in with Apple

    /// Fills the Apple request: name for the profile, and a hashed nonce.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let raw = Self.randomNonce()
        nonce = raw
        request.requestedScopes = [.fullName]
        request.nonce = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func complete(_ result: Result<ASAuthorization, any Error>) async {
        lastError = nil
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
            if case .failure(let error) = result, (error as? ASAuthorizationError)?.code == .canceled { return }
            lastError = "Apple ile giriş tamamlanamadı"
            return
        }
        do {
            let session = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: token, nonce: nonce))
            // Apple sends the name only the first time.
            let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            await sessionChanged(session.user.id)
            if !name.isEmpty, profile?.displayName?.isEmpty ?? true {
                await updateProfile(displayName: name)
            }
            UsageCounter.count(.signedIn)
        } catch {
            lastError = "Giriş yapılamadı. İnternet bağlantını kontrol et."
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        _ = try? await Purchases.shared.logOut()
        userID = nil
        profile = nil
        lastSync = nil
        try? await app?.database?.writer.write { db in try ListSync.detach(db: db) }
        await app?.reloadAfterSync()
    }

    /// Deletes the account and its lists on the server. The lists stay on this device.
    func deleteAccount() async -> Bool {
        do {
            try await client.rpc("delete_account").execute()
        } catch {
            lastError = "Hesap silinemedi. Tekrar dene."
            return false
        }
        await signOut()
        return true
    }

    // MARK: - Profile

    struct Profile: Codable, Equatable, Sendable {
        var id: UUID
        var username: String?
        var displayName: String?
        var avatar: String

        enum CodingKeys: String, CodingKey {
            case id, username, avatar
            case displayName = "display_name"
        }

        var name: String { displayName?.isEmpty == false ? displayName! : (username.map { "@" + $0 } ?? "Kelime öğrencisi") }
    }

    func loadProfile() async {
        guard let userID else { return }
        profile = try? await client.from("profiles").select().eq("id", value: userID).single().execute().value
    }

    /// Returns an error message, or nil when saved.
    @discardableResult
    func updateProfile(displayName: String? = nil, username: String? = nil, avatar: String? = nil) async -> String? {
        guard let userID else { return "Giriş yapılmadı" }
        struct Change: Encodable {
            var display_name: String?
            var username: String?
            var avatar: String?
        }
        let username = username.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        if let username, username.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) == nil {
            return "Kullanıcı adı 3–20 karakter olmalı: harf, rakam ya da _"
        }
        let change = Change(display_name: displayName.map { String($0.trimmingCharacters(in: .whitespaces).prefix(40)) }, username: username, avatar: avatar)
        do {
            profile = try await client.from("profiles").update(change).eq("id", value: userID).select().single().execute().value
            return nil
        } catch {
            if "\(error)".contains("23505") { return "Bu kullanıcı adı alınmış" }
            return "Kaydedilemedi. İnternet bağlantını kontrol et."
        }
    }

    // MARK: - Sync

    private struct ListRow: Codable {
        var id: String
        var owner: UUID?
        var title: String
        var visibility: ListVisibility
        var cards: [Card]
        var updated_at: Date?
    }

    /// Sends deletions and changed lists, then applies the account's lists. Safe to call often.
    func sync() async {
        guard let userID, let database = app?.database, !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            for id in try await database.reader.read({ db in try ListSync.pendingDeletions(db: db) }) {
                try await client.from("lists").delete().eq("id", value: id).execute()
                try await database.writer.write { db in try ListSync.deletionSent(id, db: db) }
            }
            for list in try await database.reader.read({ db in try ListSync.pendingUploads(db: db) }) {
                let row = ListRow(id: list.id, owner: userID, title: list.title, visibility: list.visibility, cards: list.cards)
                let saved: ListRow = try await client.from("lists").upsert(row).select().single().execute().value
                try await database.writer.write { db in try ListSync.uploaded(list.id, serverTime: saved.updated_at ?? .now, db: db) }
            }
            let rows: [ListRow] = try await client.from("lists").select().eq("owner", value: userID).execute().value
            let remote = rows.map { RemoteList(id: $0.id, title: $0.title, visibility: $0.visibility, cards: $0.cards, updatedAt: $0.updated_at ?? .now) }
            let changed = try await database.writer.write { db in try ListSync.merge(remote, db: db) }
            lastSync = .now
            lastError = nil
            if changed { await app?.reloadAfterSync() }
        } catch {
            lastError = "Senkronize edilemedi"
        }
    }

    // MARK: - Keşfet

    struct DiscoverItem: Decodable, Identifiable, Hashable, Sendable {
        var id: String
        var title: String
        var word_count: Int
        var saves: Int
        var owner: UUID
        var username: String?
        var display_name: String?
        var avatar: String

        var ownerName: String { display_name?.isEmpty == false ? display_name! : (username.map { "@" + $0 } ?? "Kelime öğrencisi") }
    }

    struct SharedItem: Decodable, Sendable {
        var id: String
        var title: String
        var cards: [Card]
        var word_count: Int
        var saves: Int
        var owner: UUID
        var username: String?
        var display_name: String?
        var avatar: String

        var ownerName: String { display_name?.isEmpty == false ? display_name! : (username.map { "@" + $0 } ?? "Kelime öğrencisi") }
    }

    enum DiscoverSort: String, CaseIterable { case popular, new }

    func discover(search: String, sort: DiscoverSort, page: Int) async throws -> [DiscoverItem] {
        struct Params: Encodable, Sendable { var search: String; var sort: String; var page_size: Int; var page: Int }
        return try await client.rpc("discover", params: Params(search: search, sort: sort.rawValue, page_size: 30, page: page)).execute().value
    }

    /// A public or link list (or the learner's own), nil when it is private, hidden or gone.
    func sharedList(_ id: String) async throws -> SharedItem? {
        struct Params: Encodable, Sendable { var list_id: String }
        let rows: [SharedItem] = try await client.rpc("shared_list", params: Params(list_id: id)).execute().value
        return rows.first
    }

    /// Counts a save for Keşfet's "popular" order (only when signed in).
    func recordSave(_ listID: String) async {
        guard let userID else { return }
        struct Save: Encodable { var user_id: UUID; var list_id: String }
        _ = try? await client.from("list_saves").upsert(Save(user_id: userID, list_id: listID)).execute()
    }

    func report(_ listID: String, reason: String) async -> Bool {
        guard let userID else { return false }
        struct Report: Encodable { var list_id: String; var reporter: UUID; var reason: String }
        do {
            try await client.from("reports").upsert(Report(list_id: listID, reporter: userID, reason: String(reason.prefix(200))), onConflict: "list_id,reporter").execute()
            return true
        } catch {
            return false
        }
    }

    /// Sends a card error report or a suggestion. Works without an account.
    func sendFeedback(kind: String, card: Card?, reason: String, note: String) async -> Bool {
        struct Feedback: Encodable {
            var kind: String
            var card_id: String?
            var word: String?
            var reason: String
            var note: String
            var app_version: String
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let row = Feedback(
            kind: kind,
            card_id: card.map { String($0.id.prefix(80)) },
            word: card.map { String($0.word.prefix(120)) },
            reason: String(reason.prefix(60)),
            note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)),
            app_version: "\(version) (\(build))"
        )
        do {
            try await client.from("feedback").insert(row).execute()
            return true
        } catch {
            return false
        }
    }

    func block(_ owner: UUID) async -> Bool {
        guard let userID, owner != userID else { return false }
        struct Block: Encodable { var blocker: UUID; var blocked: UUID }
        do {
            try await client.from("blocks").upsert(Block(blocker: userID, blocked: owner)).execute()
            return true
        } catch {
            return false
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }
}
