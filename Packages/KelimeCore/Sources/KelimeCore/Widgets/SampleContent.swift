import Foundation

/// Sample cards from the design brief, for SwiftUI previews and widget gallery placeholders.
public enum SampleContent {
    public static let reluctant = Card(id: "b2-reluctant", word: "reluctant", pos: .adjective, level: .b2, tr: ["isteksiz", "gönülsüz"], exampleEN: "She was reluctant to leave.", exampleTR: "Ayrılmaya gönülsüzdü.")
    public static let reliable = Card(id: "b1-reliable", word: "reliable", pos: .adjective, level: .b1, tr: ["güvenilir"], exampleEN: "He is a reliable friend.", exampleTR: "O, güvenilir bir arkadaş.")
    public static let hesitate = Card(id: "b2-hesitate", word: "hesitate", pos: .verb, level: .b2, tr: ["tereddüt etmek"], exampleEN: "Don't hesitate to ask.", exampleTR: "Sormaktan çekinme.")
    public static let significant = Card(id: "b2-significant", word: "significant", pos: .adjective, level: .b2, tr: ["önemli", "kayda değer"], exampleEN: "There was a significant increase in prices.", exampleTR: "Fiyatlarda kayda değer bir artış oldu.")
    public static let consequence = Card(id: "b2-consequence", word: "consequence", pos: .noun, level: .b2, tr: ["sonuç"], exampleEN: "Every choice has a consequence.", exampleTR: "Her seçimin bir sonucu vardır.")
    // A1 words: what a new learner sees in onboarding, settings previews and the widget gallery.
    public static let happy = Card(id: "a1-happy", word: "happy", pos: .adjective, level: .a1, tr: ["mutlu"], exampleEN: "I am happy today.", exampleTR: "Bugün mutluyum.")
    public static let coffee = Card(id: "a1-coffee", word: "coffee", pos: .noun, level: .a1, tr: ["kahve"], exampleEN: "I'd like a coffee, please.", exampleTR: "Bir kahve alayım, lütfen.")
    public static let friend = Card(id: "a1-friend", word: "friend", pos: .noun, level: .a1, tr: ["arkadaş"], exampleEN: "This is my friend.", exampleTR: "Bu benim arkadaşım.")
    public static let hungry = Card(id: "a1-hungry", word: "hungry", pos: .adjective, level: .a1, tr: ["aç"], exampleEN: "Are you hungry? Let's eat.", exampleTR: "Aç mısın? Hadi yiyelim.")
    /// Longest-content edge case: 16 + 26 + 52 characters.
    /// The longest A1 phrase card, for checking that phrases fit the widgets.
    public static let phrase = Card(id: "a1-p-at-home", word: "Make yourself at home.", pos: .phrase, level: .a1, tr: ["Kendi evin gibi rahat et."], exampleEN: "Come in! Make yourself at home.", exampleTR: "Buyurun! Kendi eviniz gibi rahat edin.")
    public static let longest = Card(id: "c1-misunderstanding", word: "misunderstanding", pos: .noun, level: .c1, tr: ["yanlış anlama", "anlaşmazlık"], exampleEN: "There was a significant increase in prices last year.", exampleTR: "Geçen yıl fiyatlarda kayda değer bir artış oldu.")

    public static func snapshot(
        _ card: Card = happy,
        state: LearningState = .struggling,
        mode: WidgetMode = .card,
        phase: WidgetSnapshot.Phase = .answer,
        quizAnswer: String? = nil,
        date: Date = .now
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            date: date,
            card: card,
            state: state,
            mode: mode,
            phase: phase,
            quizOptions: [card.word, card.id == hungry.id ? happy.word : hungry.word],
            quizAnswer: quizAnswer,
            reviewedToday: 7,
            struggling: [hungry, coffee, friend],
            puzzleProgress: .init(solved: 2, total: 5)
        )
    }
}
