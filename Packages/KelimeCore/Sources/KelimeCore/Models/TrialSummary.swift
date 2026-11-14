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

/// One stat tile of the end-of-trial summary.
public struct TrialTile: Sendable, Equatable {
    public let value: String
    public let label: String
}

extension TrialSummary {
    public static let freeKept = ["Kilit ekranı widget'ı", "Günün Bulmacası", "Sınırsız oyunlar",
                                  "Arşivden haftada 2 bulmaca", "İlk listen"]
    public static let proUnlocks = ["Bulmaca arşivi sınırsız", "Sana Özel Bulmaca",
                                    "Sınav planı ve geri sayım", "Sınırsız liste"]

    /// The stat tiles in order. Tiles with value 0 are dropped, except the first two.
    /// `ownLists` counts the learner's own lists; only lists beyond the first count as "Kendi listen".
    public static func tiles(wordsStudied: Int, streakDays: Int, usage: [String: Int],
                             ownLists: Int, examPercent: Int?) -> [TrialTile] {
        func uses(_ f: TrialFeature) -> Int { usage[f.rawValue] ?? 0 }
        let all: [(Int, String, String)] = [
            (wordsStudied, "\(wordsStudied)", "Çalışılan kelime"),
            (streakDays, "\(streakDays)", "Gün seri"),
            (uses(.archive), "\(uses(.archive))", "Arşivden bulmaca"),
            (uses(.personalPuzzle), "\(uses(.personalPuzzle))", "Sana Özel Bulmaca"),
            (ownLists > 1 ? ownLists : 0, "\(ownLists)", "Kendi listen"),
            (examPercent ?? 0, "%\(examPercent ?? 0)", "Sınav planı"),
        ]
        return all.enumerated().filter { $0.offset < 2 || $0.element.0 > 0 }
            .map { TrialTile(value: $0.element.1, label: $0.element.2) }
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
