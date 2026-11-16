import Foundation

/// Keeps the answer of a multiple-choice question from showing through its punctuation or
/// capital letters (docs/SYNC.md, "Hızlı Tekrar: noktalama cevabı ele vermesin"). Used by every
/// generator that shows English options: Quick Review and the quiz widgets / Watch
/// (`CardQueries.quizOptions`) and Boşluğu Doldur (`GapFill`).
public enum OptionStyle {
    /// The sentence type of an option: its last meaningful character.
    public enum Ending: Sendable, Equatable { case question, exclamation, plain }

    private static let closers: Set<Character> = ["\"", "'", "\u{201D}", "\u{2019}", ")", "]"]
    private static let trailing: Set<Character> = [".", ",", "!", "?", ";", ":", "\u{2026}"]

    /// `?` and `!` are their own types; `.`, other punctuation and no punctuation are one.
    /// Trailing spaces, quotes and brackets are skipped.
    public static func ending(of text: String) -> Ending {
        for ch in text.reversed() where !ch.isWhitespace && !closers.contains(ch) {
            switch ch {
            case "?": return .question
            case "!": return .exclamation
            default: return .plain
            }
        }
        return .plain
    }

    /// The text without trailing punctuation (`. , ! ? ; : …`, repeated) and trailing spaces.
    public static func strippingEnd(_ text: String) -> String {
        var s = Substring(text)
        while let last = s.last, last.isWhitespace || trailing.contains(last) { s = s.dropLast() }
        return String(s)
    }

    /// How close `other` is to `answer` in shape: 2 when it has the same ending type and also
    /// reads as a sentence (or not) like the answer, 1 for the same ending type only, 0 otherwise.
    /// Generators try 2, then 1 (the rule), then 0 (the endings are stripped afterwards).
    public static func likeness(of other: String, to answer: String) -> Int {
        guard ending(of: other) == ending(of: answer) else { return 0 }
        return isSentence(other) == isSentence(answer) ? 2 : 1
    }

    /// Whether the option reads as a sentence: it ends in `. ? ! …` (quotes skipped).
    static func isSentence(_ text: String) -> Bool {
        for ch in text.reversed() where !ch.isWhitespace && !closers.contains(ch) {
            return [".", "?", "!", "\u{2026}"].contains(ch)
        }
        return false
    }

    private static func isMultiWord(_ text: String) -> Bool {
        text.split(whereSeparator: \.isWhitespace).count > 1
    }

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first, first.isLowercase else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Lowers the first letter, but keeps "I", "I'm" and words that start with two capitals.
    private static func lowered(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }
        let rest = text.dropFirst()
        if first == "I", rest.first.map({ !$0.isLetter }) ?? true { return text }
        if let second = rest.first, second.isUppercase { return text }
        return first.lowercased() + rest
    }

    /// The answer and the wrong options as they are shown. All four share one ending type, or
    /// else all lose their trailing punctuation; multi-word options all start with a capital
    /// letter (the answer is a sentence) or all with a small one. Single words stay as they are.
    public static func styled(answer: String, wrong: [String]) -> (answer: String, wrong: [String]) {
        var all = [answer] + wrong
        let kind = ending(of: answer)
        if all.contains(where: { ending(of: $0) != kind }) {
            all = all.map(strippingEnd)
        }
        let sentence = isSentence(answer)
        all = all.map { option in
            guard isMultiWord(option) else { return option }
            return sentence ? capitalized(option) : lowered(option)
        }
        return (all[0], Array(all.dropFirst()))
    }

    /// Whether a shown `option` is the card's `word`, however it was styled.
    public static func isAnswer(_ option: String, word: String) -> Bool {
        func key(_ s: String) -> String { strippingEnd(s).lowercased() }
        return option == word || key(option) == key(word)
    }
}
