import KelimeCore
import KelimeUI
import SwiftUI

/// A card error report ("Bu kartta hata mı var?") or a suggestion, sent from inside the app.
struct FeedbackForm: View {
    /// The card being reported; nil for a general suggestion.
    let card: Card?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var reason: String?
    @State private var note = ""
    @State private var sending = false
    @State private var failed = false
    @State private var sent = false
    @FocusState private var noteFocused: Bool

    private var reasons: [String] {
        card == nil
            ? ["Öneri", "Hata ya da sorun", "Kelime ya da liste isteği", "Diğer"]
            : ["Anlam yanlış", "Örnek cümle hatalı", "Yazım hatası", "Türü ya da seviyesi yanlış", "Telaffuz", "Diğer"]
    }

    /// A card report can be just a reason; a suggestion or "Diğer" needs words.
    private var canSend: Bool {
        let hasNote = !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return reason != nil && (hasNote || (card != nil && reason != "Diğer"))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let card {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.word).font(KelimeFont.english(26, relativeTo: .title2))
                            Text(card.meaning).font(KelimeFont.ui(15, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        caption(card == nil ? "NE HAKKINDA?" : "NE YANLIŞ?")
                        FlowLayout(spacing: 8) {
                            ForEach(reasons, id: \.self) { item in
                                chip(item)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        caption(card == nil ? "MESAJIN" : "NOT (İSTEĞE BAĞLI)")
                        TextField(card == nil ? "Ne düşünüyorsun?" : "Doğrusu ne olmalı?", text: $note, axis: .vertical)
                            .lineLimit(4...8)
                            .focused($noteFocused)
                            .font(KelimeFont.ui(15, relativeTo: .body))
                            .padding(12)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
                    }
                    if failed {
                        Text("Gönderilemedi. İnternet bağlantını kontrol edip tekrar dene.")
                            .font(KelimeFont.ui(13, relativeTo: .footnote))
                            .foregroundStyle(Palette.amberInk)
                    }
                    Text("Adın ya da e-postan gönderilmez; yalnızca seçtiğin neden, notun ve uygulama sürümü.")
                        .font(KelimeFont.ui(12, relativeTo: .caption))
                        .foregroundStyle(Palette.ink2)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button { Task { await send() } } label: {
                    Group {
                        if sending { ProgressView().tint(Palette.onAccent) } else { Text("Gönder") }
                    }
                    .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Palette.accent.opacity(canSend ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSend || sending)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle(card == nil ? "Öneri gönder" : "Kartı bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } }
            }
            .overlay {
                if sent { thanks }
            }
        }
    }

    private var thanks: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.green)
            Text("Teşekkürler!").font(KelimeFont.ui(20, weight: .semibold, relativeTo: .title3))
            Text(card == nil ? "Mesajın bize ulaştı." : "Kartı inceleyip düzelteceğiz.")
                .font(KelimeFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .transition(.opacity)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(KelimeFont.ui(12, weight: .semibold, relativeTo: .caption))
            .tracking(0.7)
            .foregroundStyle(Palette.ink2)
    }

    private func chip(_ item: String) -> some View {
        let selected = reason == item
        return Button {
            reason = item
            if item == "Diğer" { noteFocused = true }
        } label: {
            Text(item)
                .font(KelimeFont.ui(14, weight: selected ? .semibold : .regular, relativeTo: .subheadline))
                .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(selected ? Palette.accent : Palette.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? .clear : Palette.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func send() async {
        guard let reason else { return }
        sending = true
        failed = false
        let ok = await app.account.sendFeedback(kind: card == nil ? "suggestion" : "card", card: card, reason: reason, note: note)
        sending = false
        if ok {
            withAnimation { sent = true }
            try? await Task.sleep(for: .seconds(1.4))
            dismiss()
        } else {
            failed = true
        }
    }
}

