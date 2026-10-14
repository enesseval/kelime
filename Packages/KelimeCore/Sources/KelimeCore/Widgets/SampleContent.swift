import Foundation

/// Sample cards from the design brief, for SwiftUI previews and widget gallery placeholders.
public enum SampleContent {
    public static let reluctant = Card(id: "b2-reluctant", word: "reluctant", pos: .adjective, level: .b2, tr: ["isteksiz", "gönülsüz"], exampleEN: "She was reluctant to leave.", exampleTR: "Ayrılmaya gönülsüzdü.")
    public static let reliable = Card(id: "b1-reliable", word: "reliable", pos: .adjective, level: .b1, tr: ["güvenilir"], exampleEN: "He is a reliable friend.", exampleTR: "O, güvenilir bir arkadaş.")
    public static let hesitate = Card(id: "b2-hesitate", word: "hesitate", pos: .verb, level: .b2, tr: ["tereddüt etmek"], exampleEN: "Don't hesitate to ask.", exampleTR: "Sormaktan çekinme.")
    public static let significant = Card(id: "b2-significant", word: "significant", pos: .adjective, level: .b2, tr: ["önemli", "kayda değer"], exampleEN: "There was a significant increase in prices.", exampleTR: "Fiyatlarda kayda değer bir artış oldu.")
    public static let consequence = Card(id: "b2-consequence", word: "consequence", pos: .noun, level: .b2, tr: ["sonuç"], exampleEN: "Every choice has a consequence.", exampleTR: "Her seçimin bir sonucu vardır.")
    /// Longest-content edge case: 16 + 26 + 52 characters.
    public static let longest = Card(id: "c1-misunderstanding", word: "misunderstanding", pos: .noun, level: .c1, tr: ["yanlış anlama", "anlaşmazlık"], exampleEN: "There was a significant increase in prices last year.", exampleTR: "Geçen yıl fiyatlarda kayda değer bir artış oldu.")

    public static func snapshot(
        _ card: Card = reluctant,
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
            quizOptions: [card.word, card.id == reliable.id ? reluctant.word : reliable.word],
            quizAnswer: quizAnswer,
            reviewedToday: 7,
            struggling: [reluctant, significant, consequence],
            puzzleProgress: .init(solved: 2, total: 5)
        )
    }
}
