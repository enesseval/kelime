import Foundation

/// The lines of the end-of-trial summary: the Pro features the learner used in the 3 days,
/// with numbers. Features not used are not listed.
public enum TrialSummary {
    /// `ownLists` counts the learner's own lists; `examPercent` is the share of the exam list
    /// learned (nil without an exam plan). Zeros are not listed.
    public static func lines(usage: [String: Int], ownLists: Int, examPercent: Int?) -> [String] {
        func uses(_ f: TrialFeature) -> Int { usage[f.rawValue] ?? 0 }
        var lines: [String] = []
        if uses(.archive) > 0 { lines.append("Arşivden \(uses(.archive)) bulmaca") }
        if uses(.personalPuzzle) > 0 { lines.append("Sana özel \(uses(.personalPuzzle)) bulmaca") }
        if ownLists > 1 { lines.append("\(ownLists) kendi listen") }
        if let examPercent, examPercent > 0 { lines.append("Sınav planın %\(examPercent)") }
        return lines
    }
}

/// The free games, in the order Günün Bulmacası's result suggests them.
public enum FreeGame: String, Sendable, CaseIterable {
    case wordSearch, match, sentence, gapFill

    /// The next free game after the daily puzzle: the first one not played today, else the first.
    public static func next(playedToday: Set<FreeGame>) -> FreeGame {
        allCases.first { !playedToday.contains($0) } ?? allCases[0]
    }
}
