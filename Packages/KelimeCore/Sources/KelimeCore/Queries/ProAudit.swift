import Foundation
import GRDB

/// One paywall promise and whether the code actually delivers it.
public struct ProAuditItem: Sendable, Identifiable {
    public var id: String
    /// The promise as the paywall states it.
    public var promise: String
    public var passed: Bool
    /// What was measured, in Turkish, e.g. "24 saatte 49 kelime, 30 dk arayla".
    public var detail: String

    public init(id: String, promise: String, passed: Bool, detail: String) {
        self.id = id
        self.promise = promise
        self.passed = passed
        self.detail = detail
    }
}

/// Checks every Pro promise on the paywall against the real code paths: the widget timeline,
/// the scheduler, the review limit and the puzzle generator.
///
/// Each check runs on an in-memory copy of the user's database, once as a free user and once
/// as Pro, so it never changes the user's data or entitlement.
public enum ProAudit {
    public static func run(source: any DatabaseReader, clock: AppClock) -> [ProAuditItem] {
        [
            check("rotation30", "Kelime 30 dakikada bir değişir") { try rotation(.thirtyMinutes, source: source, clock: clock) },
            check("rotation60", "Kelime saatte bir değişir") { try rotation(.oneHour, source: source, clock: clock) },
            check("review", "Sınırsız Hızlı Tekrar") { try unlimitedReview(source: source, clock: clock) },
            check("exam", "YDS · YÖKDİL · IELTS desteleri") { try decks([.yds, .yokdil, .ielts], source: source, clock: clock) },
            check("levels", "B2–C1 kelimeler") { try decks([.b2, .c1], source: source, clock: clock) },
            check("themes", "Tüm temalar") { try themes(source: source, clock: clock) },
            check("personal", "Sana özel bulmaca") { try personalPuzzle(source: source, clock: clock) },
        ]
    }

    private static func check(_ id: String, _ promise: String, _ body: () throws -> (Bool, String)) -> ProAuditItem {
        do {
            let (passed, detail) = try body()
            return ProAuditItem(id: id, promise: promise, passed: passed, detail: detail)
        } catch {
            return ProAuditItem(id: id, promise: promise, passed: false, detail: "Hata: \(error)")
        }
    }

    // MARK: - Checks

    /// The widget timeline has a new word every `interval` for Pro, and every 3 hours for free.
    static func rotation(_ interval: RotationInterval, source: any DatabaseReader, clock: AppClock) throws -> (Bool, String) {
        let pro = try widgetGaps(source: source, clock: clock) { $0.rotationInterval = interval; $0.isPro = true }
        let free = try widgetGaps(source: source, clock: clock) { $0.rotationInterval = interval; $0.isPro = false }
        let expected = interval.minutes
        let proOK = pro.gaps.allSatisfy { $0 == expected } && pro.slots >= 24 * 60 / expected
        let freeOK = free.gaps.allSatisfy { $0 == RotationInterval.default.minutes }
        let detail = "Pro: 24 saatte \(pro.slots) kelime, \(pro.gaps.first.map { "\($0) dk" } ?? "-") arayla"
            + " · Ücretsiz: \(free.gaps.first.map { "\($0 / 60) saatte bir" } ?? "-")"
        return (proOK && freeOK, detail)
    }

    /// Free users get one Quick Review a day; Pro has no limit.
    static func unlimitedReview(source: any DatabaseReader, clock: AppClock) throws -> (Bool, String) {
        let db = try copy(source)
        return try db.write { db in
            guard let cardID = try String.fetchOne(db, sql: "SELECT id FROM card LIMIT 1") else { return (false, "Kart yok") }
            try LearningStore.record(.answered(correct: true), cardID: cardID, source: .quickReview, clock: clock, sessionID: "pro-audit", db: db)
            try setPrefs(db) { $0.isPro = false }
            let free = try QuickReviewLimit.remaining(db: db, clock: clock)
            try setPrefs(db) { $0.isPro = true }
            let pro = try QuickReviewLimit.remaining(db: db, clock: clock)
            let detail = "Bir turdan sonra · Ücretsiz: \(free.map { "\($0) hak" } ?? "sınırsız") · Pro: \(pro.map { "\($0) hak" } ?? "sınırsız")"
            return (free == 0 && pro == nil, detail)
        }
    }

    /// Each Pro deck has cards, reaches the widget for Pro, and stays off it for free users.
    static func decks(_ decks: [DeckID], source: any DatabaseReader, clock: AppClock) throws -> (Bool, String) {
        var passed = true
        var parts: [String] = []
        for deck in decks {
            let db = try copy(source)
            let (ok, text) = try db.write { db -> (Bool, String) in
                let deckCards = Set(try CardQueries.candidates(in: [deck], db: db).map(\.cardID))
                let freeCards = Set(try CardQueries.candidates(in: DeckID.freeDecks, db: db).map(\.cardID))
                let onlyPro = deckCards.subtracting(freeCards)
                let pro = try queue(db, clock: clock) { $0.enabledDecks = [deck]; $0.isPro = true }
                let free = try queue(db, clock: clock) { $0.enabledDecks = [deck]; $0.isPro = false }
                let proOK = !pro.isEmpty && pro.allSatisfy(deckCards.contains)
                let freeOK = !free.contains(where: onlyPro.contains)
                return (!deckCards.isEmpty && proOK && freeOK, "\(deck.rawValue) \(deckCards.count) kelime")
            }
            passed = passed && ok
            parts.append(ok ? text : "\(text) ✗")
        }
        return (passed, parts.joined(separator: " · "))
    }

    /// Every Pro theme reaches the widget for Pro; free users see Kâğıt.
    static func themes(source: any DatabaseReader, clock: AppClock) throws -> (Bool, String) {
        let db = try copy(source)
        return try db.write { db in
            var failed: [String] = []
            let proThemes = WidgetThemeID.allCases.filter(\.isPro)
            for theme in proThemes {
                let pro = try snapshots(db, clock: clock) { $0.theme = theme; $0.isPro = true }.first?.theme
                let free = try snapshots(db, clock: clock) { $0.theme = theme; $0.isPro = false }.first?.theme
                if pro != theme || free != .paper { failed.append(theme.name) }
            }
            let names = proThemes.map(\.name).joined(separator: ", ")
            return (failed.isEmpty, failed.isEmpty ? "\(names) widget'a ulaşıyor" : "Çalışmayan: \(failed.joined(separator: ", "))")
        }
    }

    static func personalPuzzle(source: any DatabaseReader, clock: AppClock) throws -> (Bool, String) {
        let db = try copy(source)
        return try db.write { db in
            try setPrefs(db) { $0.isPro = true }
            guard let puzzle = try PersonalPuzzle.make(db: db, clock: clock, seed: 1) else { return (false, "Bulmaca üretilemedi") }
            let problems = CrosswordValidator.problems(puzzle)
            return (problems.isEmpty, "\(puzzle.entries.count) kelimelik bulmaca üretildi" + (problems.isEmpty ? "" : " · \(problems.count) hata"))
        }
    }

    // MARK: - Helpers

    private static func copy(_ source: any DatabaseReader) throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try source.backup(to: queue)
        return queue
    }

    private static func setPrefs(_ db: Database, _ change: (inout Preferences) -> Void) throws {
        var prefs = try Preferences.load(db)
        change(&prefs)
        try prefs.save(db)
    }

    /// Card ids on a freshly built queue after `change`.
    private static func queue(_ db: Database, clock: AppClock, _ change: (inout Preferences) -> Void) throws -> [String] {
        try setPrefs(db, change)
        try WidgetQueueEntry.deleteAll(db)
        var rng = SeededGenerator(seed: 1)
        return try WidgetQueue.refill(db: db, clock: clock, using: &rng).map(\.cardID)
    }

    /// The widget's timeline entries after `change`, built the way the widget builds them.
    private static func snapshots(_ db: Database, clock: AppClock, _ change: (inout Preferences) -> Void) throws -> [WidgetSnapshot] {
        try setPrefs(db, change)
        try WidgetQueueEntry.deleteAll(db)
        var rng = SeededGenerator(seed: 1)
        return try WidgetTimelineBuilder.build(db: db, clock: clock, mode: .card, using: &rng)
    }

    /// Minutes between consecutive words on the widget timeline, and how many words it holds.
    private static func widgetGaps(
        source: any DatabaseReader,
        clock: AppClock,
        _ change: @escaping (inout Preferences) -> Void
    ) throws -> (slots: Int, gaps: [Int]) {
        let db = try copy(source)
        let starts = try db.write { db in
            Array(Set(try snapshots(db, clock: clock, change).filter { !$0.isEmpty }.map(\.slotStart))).sorted()
        }
        let gaps = zip(starts, starts.dropFirst()).map { Int($1.timeIntervalSince($0) / 60) }
        return (starts.count, gaps)
    }
}
