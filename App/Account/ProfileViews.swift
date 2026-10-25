import AuthenticationServices
import KelimeCore
import KelimeUI
import SwiftUI

/// Preset avatars: a symbol on a colour. "letter" (the default) shows the name's first letter.
enum Avatar {
    static let letter = "letter"

    struct Preset: Identifiable {
        let id: String
        let symbol: String
        let color: Color
    }

    static let presets: [Preset] = [
        Preset(id: "fox", symbol: "hare.fill", color: Color(red: 0.93, green: 0.49, blue: 0.27)),
        Preset(id: "tortoise", symbol: "tortoise.fill", color: Color(red: 0.36, green: 0.62, blue: 0.40)),
        Preset(id: "bird", symbol: "bird.fill", color: Color(red: 0.27, green: 0.55, blue: 0.86)),
        Preset(id: "fish", symbol: "fish.fill", color: Color(red: 0.20, green: 0.66, blue: 0.72)),
        Preset(id: "cat", symbol: "cat.fill", color: Color(red: 0.55, green: 0.45, blue: 0.80)),
        Preset(id: "dog", symbol: "dog.fill", color: Color(red: 0.70, green: 0.52, blue: 0.36)),
        Preset(id: "ladybug", symbol: "ladybug.fill", color: Color(red: 0.86, green: 0.30, blue: 0.32)),
        Preset(id: "leaf", symbol: "leaf.fill", color: Color(red: 0.42, green: 0.70, blue: 0.30)),
        Preset(id: "star", symbol: "star.fill", color: Color(red: 0.92, green: 0.70, blue: 0.20)),
        Preset(id: "moon", symbol: "moon.stars.fill", color: Color(red: 0.26, green: 0.30, blue: 0.58)),
        Preset(id: "sun", symbol: "sun.max.fill", color: Color(red: 0.96, green: 0.58, blue: 0.20)),
        Preset(id: "bolt", symbol: "bolt.fill", color: Color(red: 0.95, green: 0.78, blue: 0.18)),
        Preset(id: "flame", symbol: "flame.fill", color: Color(red: 0.90, green: 0.38, blue: 0.22)),
        Preset(id: "book", symbol: "book.fill", color: Color(red: 0.40, green: 0.48, blue: 0.56)),
        Preset(id: "globe", symbol: "globe.europe.africa.fill", color: Color(red: 0.22, green: 0.58, blue: 0.56)),
    ]
}

struct AvatarView: View {
    let avatar: String
    let name: String
    var size: CGFloat = 44

    var body: some View {
        let preset = Avatar.presets.first { $0.id == avatar }
        ZStack {
            Circle().fill(preset?.color ?? Palette.accent)
            if let preset {
                Image(systemName: preset.symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.onAccent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var initial: String {
        let letters = name.drop { $0 == "@" }
        return letters.first.map { String($0).uppercased(with: Locale(identifier: "tr_TR")) } ?? "K"
    }
}

/// Profil › HESAP: Sign in with Apple, or the profile with sync, sign out and account deletion.
struct AccountSection: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var colorScheme
    @State private var editing = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        let account = app.account
        SettingsSection("HESAP") {
            if let profile = account.profile, account.isSignedIn {
                Button { editing = true } label: {
                    HStack(spacing: 14) {
                        AvatarView(avatar: profile.avatar, name: profile.name, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.name).font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline)).foregroundStyle(Palette.ink)
                            Text(profile.username.map { "@" + $0 } ?? "Kullanıcı adı seç")
                                .font(KelimeFont.ui(13, relativeTo: .footnote))
                                .foregroundStyle(profile.username == nil ? Palette.accent : Palette.ink2)
                        }
                        Spacer()
                        Text("Düzenle ›").font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.line)
                SettingsRow("Listelerim") {
                    if account.syncing {
                        ProgressView()
                    } else {
                        Button(syncLabel) { Task { await account.sync() } }
                            .font(KelimeFont.ui(14, relativeTo: .subheadline))
                            .foregroundStyle(account.lastError == nil ? Palette.ink2 : Palette.amberInk)
                    }
                }
                Divider().overlay(Palette.line)
                Button { confirmSignOut = true } label: {
                    rowText("Çıkış yap", color: Palette.ink)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.line)
                Button { confirmDelete = true } label: {
                    rowText("Hesabı sil", color: Palette.amberInk)
                }
                .buttonStyle(.plain)
            } else if account.isSignedIn {
                SettingsRow("Hesap yükleniyor") { ProgressView() }
                    .task { await account.loadProfile() }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hesabını bağla")
                        .font(KelimeFont.ui(17, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Palette.ink)
                    Text("Listelerin yedeklenir ve cihazlarında eşitlenir. Listelerini linkle paylaşabilir ya da Keşfet'te herkese açabilirsin. Pro'n da hesabına bağlanır.")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    SignInWithAppleButton(.continue) { request in
                        account.prepare(request)
                    } onCompletion: { result in
                        Task { await account.complete(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    if let error = account.lastError {
                        Text(error).font(KelimeFont.ui(12, relativeTo: .caption)).foregroundStyle(Palette.amberInk)
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $editing) { ProfileEditor().environment(app) }
        .confirmationDialog("Çıkış yapılsın mı?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Çıkış yap", role: .destructive) { Task { await account.signOut() } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Listelerin bu cihazda kalır; paylaşımları kapanır.")
        }
        .confirmationDialog("Hesabın silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Hesabı kalıcı olarak sil", role: .destructive) { Task { _ = await account.deleteAccount() } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Hesabın, profilin ve sunucudaki listelerin silinir. Bu cihazdaki listeler ve ilerlemen kalır. Pro aboneliğini iptal etmek için iPhone Ayarlar › Abonelikler'i kullan.")
        }
    }

    private var syncLabel: String {
        if app.account.lastError != nil { return "Tekrar dene" }
        guard let last = app.account.lastSync else { return "Eşitle" }
        return "Eşitlendi · " + last.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(Locale(identifier: "tr_TR")))
    }

    private func rowText(_ title: String, color: Color) -> some View {
        Text(title)
            .font(KelimeFont.ui(15, relativeTo: .body))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// Name, username and avatar.
struct ProfileEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var avatar = Avatar.letter
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarView(avatar: avatar, name: name.isEmpty ? username : name, size: 84)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        avatarChoice(Avatar.letter)
                        ForEach(Avatar.presets) { preset in avatarChoice(preset.id) }
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    TextField("Adın", text: $name)
                    HStack(spacing: 2) {
                        Text("@").foregroundStyle(Palette.ink2)
                        TextField("kullanici_adi", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    Text("Herkese açık listelerinin yanında adın ve avatarın görünür.")
                }
                if let error {
                    Text(error).foregroundStyle(Palette.amberInk)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Kaydet") { Task { await save() } }.fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                let profile = app.account.profile
                name = profile?.displayName ?? ""
                username = profile?.username ?? ""
                avatar = profile?.avatar ?? Avatar.letter
            }
        }
    }

    private func avatarChoice(_ id: String) -> some View {
        Button { avatar = id } label: {
            AvatarView(avatar: id, name: name.isEmpty ? username : name, size: 42)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: avatar == id ? 3 : 0).padding(-4))
                .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id == Avatar.letter ? "Baş harf" : id)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        error = await app.account.updateProfile(displayName: name, username: trimmed.isEmpty ? nil : trimmed, avatar: avatar)
        if error == nil { dismiss() }
    }
}
