import KelimeCore
import KelimeUI
import SwiftUI

struct WordDetailView: View {
    @Environment(AppModel.self) private var model
    let cardID: String

    @State private var item: WordItem?
    @State private var missing = false
    @State private var sharing = false
    @State private var reporting = false
    @State private var toast: String?

    var body: some View {
        Group {
            if let item {
                content(item)
            } else if missing {
                ContentUnavailableView("Kelime bulunamadı", systemImage: "text.magnifyingglass")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await model.setFavorite(!item.favorite, cardID: item.id) }
                    } label: {
                        Image(systemName: item.favorite ? "star.fill" : "star")
                            .foregroundStyle(item.favorite ? Palette.amber : Palette.ink2)
                    }
                    .accessibilityLabel(item.favorite ? "Favorilerden çıkar" : "Favorilere ekle")
                    Button { sharing = true } label: {
                        Text("Paylaş").font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                    }
                }
            }
        }
        .tint(Palette.accent)
        .task(id: model.dataVersion) {
            let id = cardID
            item = await model.read { db in try WordQueries.item(id: id, db: db) } ?? nil
            missing = item == nil
        }
        .sheet(isPresented: $sharing) {
            if let item { ShareCardSheet(card: item.card) }
        }
        .sheet(isPresented: $reporting) {
            if let item { FeedbackForm(card: item.card).environment(model) }
        }
        .toast($toast)
    }

    /// "Sonraki tekrar: 3 Kasım", or that the review is due.
    private func nextReviewText(_ day: LocalDate) -> String {
        if day.days(since: model.clock.today) <= 0 { return "Tekrar zamanı geldi; widget'ta ve Hızlı Tekrar'da çıkacak" }
        let date = day.startDate(in: .current).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "tr_TR")))
        return "Sonraki tekrar: \(date)"
    }

    private func content(_ item: WordItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        StateChip(item.state, size: 12)
                        LevelChip(item.card.level, size: 12)
                        Text(item.deckLabel)
                            .font(KelimeFont.ui(12, weight: .semibold))
                            .foregroundStyle(Palette.ink2)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.line))
                    }
                    Text(item.card.word)
                        .font(KelimeFont.english(64, relativeTo: .largeTitle))
                        .tracking(-1.6)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 12) {
                        Button {
                            Speaker.shared.speak(item.card.word)
                        } label: {
                            Label("Dinle", systemImage: "play.fill")
                                .font(KelimeFont.ui(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(Palette.surface2, in: Capsule())
                        }
                        .accessibilityLabel("Telaffuzu dinle")
                        Text(item.card.pos.abbreviation)
                            .font(KelimeFont.english(18, relativeTo: .body, italic: true))
                            .foregroundStyle(Palette.ink2)
                    }
                }
                Rectangle().fill(Palette.line).frame(height: 1)
                section("ANLAMI") {
                    Text(item.card.meaning).font(KelimeFont.ui(22, weight: .medium, relativeTo: .title2))
                }
                if !item.card.exampleEN.isEmpty {
                    section("ÖRNEK") {
                        Text(item.card.exampleEN).font(KelimeFont.english(22, relativeTo: .title2, italic: true))
                        if !item.card.exampleTR.isEmpty {
                            Text(item.card.exampleTR).font(KelimeFont.ui(15, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                        }
                    }
                }
                if let next = item.nextReview {
                    Label(nextReviewText(next), systemImage: "arrow.clockwise")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                }
                if let senses = item.card.senses, !senses.isEmpty {
                    section("DİĞER ANLAMLAR") {
                        ForEach(senses, id: \.self) { sense in
                            VStack(alignment: .leading, spacing: 3) {
                                (Text(sense.pos.abbreviation + "  ").font(KelimeFont.english(16, relativeTo: .body, italic: true)).foregroundStyle(Palette.ink2)
                                    + Text(sense.meaning).font(KelimeFont.ui(18, weight: .medium, relativeTo: .body)))
                                Text(sense.exampleEN).font(KelimeFont.english(18, relativeTo: .body, italic: true))
                                Text(sense.exampleTR).font(KelimeFont.ui(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink2)
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
                if let note = item.card.note, !note.isEmpty {
                    section("DİKKAT") {
                        Text(note)
                            .font(KelimeFont.ui(15, relativeTo: .subheadline))
                            .foregroundStyle(Palette.amberInk)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.amberBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                if !item.card.id.hasPrefix(UserLists.customPrefix) {
                    Button { reporting = true } label: {
                        Label("Bu kartta hata mı var? Bildir", systemImage: "exclamationmark.bubble")
                            .font(KelimeFont.ui(13, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(Palette.ink2)
                            .frame(minHeight: 44)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        // The two answers stay on the bottom edge, so the screen reads as one page that ends
        // in its actions instead of stopping halfway down.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions(item)
        }
    }

    private func actions(_ item: WordItem) -> some View {
        HStack(spacing: 10) {
            Button("Biliyorum") {
                Task {
                    await model.record(.markedKnown, cardID: item.id, source: .wordDetail)
                    toast = "Öğrenildi olarak işaretlendi"
                }
            }
            .buttonStyle(TintedButtonStyle(ink: Palette.greenInk, background: Palette.greenBackground, height: 56))
            Button("Zorlanıyorum") {
                Task {
                    await model.record(.markedStruggling, cardID: item.id, source: .wordDetail)
                    toast = "Bu kelimeyi widget'ında daha sık göreceksin"
                }
            }
            .buttonStyle(TintedButtonStyle(ink: Palette.amberInk, background: Palette.amberBackground, height: 56))
        }
        .padding(10)
        .floatingGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), fallback: Palette.background)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KelimeFont.ui(11, weight: .semibold, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(Palette.ink2)
            content()
        }
    }
}
