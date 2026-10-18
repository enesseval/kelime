import Foundation
import GRDB

/// What the iPhone sends the Apple Watch: the widget's next 24 hours of words, plus today's
/// review count. The watch has no database of its own; its app and complications read this.
///
/// The phone builds it from the same queue as the iPhone widget, so the wrist and the lock
/// screen always show the same word.
public struct WatchPayload: Codable, Sendable, Equatable {
    public struct Slot: Codable, Sendable, Equatable {
        public var start: Date
        public var card: Card
        public var state: LearningState
        /// The answer plus one wrong option, for the watch's mini quiz.
        public var quizOptions: [String]
        public var quizAnswer: String?

        public init(start: Date, card: Card, state: LearningState, quizOptions: [String], quizAnswer: String? = nil) {
            self.start = start
            self.card = card
            self.state = state
            self.quizOptions = quizOptions
            self.quizAnswer = quizAnswer
        }
    }

    public var generatedAt: Date
    public var slots: [Slot]
    public var reviewedToday: Int
    /// The local day `reviewedToday` counts; the count resets after it.
    public var reviewedDay: LocalDate
    public var dailyTarget: Int
    /// The app's default widget mode (Kart, Sözlük, Kendini sına…).
    public var mode: WidgetMode
    /// Kendini sına: how long after a slot starts the answer appears.
    public var revealDelay: TimeInterval

    public init(
        generatedAt: Date, slots: [Slot], reviewedToday: Int, reviewedDay: LocalDate,
        dailyTarget: Int = WidgetTimelineBuilder.dailyTarget, mode: WidgetMode = .card, revealDelay: TimeInterval = 0
    ) {
        self.generatedAt = generatedAt
        self.slots = slots
        self.reviewedToday = reviewedToday
        self.reviewedDay = reviewedDay
        self.dailyTarget = dailyTarget
        self.mode = mode
        self.revealDelay = revealDelay
    }

    /// Builds the payload on the phone. Refills the widget queue first, so this writes.
    public static func make(db: Database, clock: AppClock, using rng: inout some RandomNumberGenerator) throws -> WatchPayload {
        let prefs = try Preferences.load(db)
        let queue = try WidgetQueue.refill(db: db, clock: clock, using: &rng)
        let ids = Array(Set(queue.map(\.cardID)))
        let cards = Dictionary(uniqueKeysWithValues: try Card.fetchAll(db, keys: ids).map { ($0.id, $0) })
        let states = Dictionary(uniqueKeysWithValues: try CardState.fetchAll(db, keys: ids).map { ($0.cardID, $0.state) })
        let slots = queue.compactMap { entry -> Slot? in
            guard let card = cards[entry.cardID] else { return nil }
            return Slot(start: entry.slotStart, card: card, state: states[card.id] ?? .new,
                        quizOptions: entry.quizOptions, quizAnswer: entry.quizAnswer)
        }
        let today = clock.today
        return WatchPayload(
            generatedAt: clock.now,
            slots: slots,
            reviewedToday: try WidgetTimelineBuilder.reviewCount(on: today, db: db),
            reviewedDay: today,
            mode: prefs.defaultWidgetMode,
            revealDelay: WidgetTimelineBuilder.revealDelay(for: prefs.effectiveRotation)
        )
    }

    // MARK: - Reading on the watch

    /// The slot on screen at `date`. Past the last slot (the phone has not sent an update for
    /// a day), the words repeat in order instead of the watch going blank.
    public func slot(at date: Date) -> Slot? {
        guard let first = slots.first else { return nil }
        if let current = slots.last(where: { $0.start <= date }), date < end { return current }
        if date < first.start { return first }
        let span = end.timeIntervalSince(first.start)
        guard span > 0 else { return slots.last }
        let offset = date.timeIntervalSince(first.start).truncatingRemainder(dividingBy: span)
        let shifted = first.start.addingTimeInterval(offset)
        return slots.last { $0.start <= shifted } ?? first
    }

    /// When the last slot ends: one rotation step after it starts.
    public var end: Date {
        guard let last = slots.last else { return generatedAt }
        let step = slots.count > 1 ? last.start.timeIntervalSince(slots[slots.count - 2].start) : 3 * 3600
        return last.start.addingTimeInterval(step)
    }

    /// Answers logged today as seen from the watch: 0 once the counted day is over.
    public func reviewed(on day: LocalDate) -> Int {
        day == reviewedDay ? reviewedToday : 0
    }

    /// Widget entries from `now` on, the same shape the iPhone widget renders.
    public func snapshots(from now: Date, calendar: Calendar) -> [WidgetSnapshot] {
        let upcoming = slots.filter { $0.start > now }
        var starts = [now] + upcoming.map(\.start)
        // No update from the phone for a day: keep a day of repeated words on the timeline.
        if upcoming.isEmpty, slots.count > 1 {
            let step = slots[1].start.timeIntervalSince(slots[0].start)
            if step > 0 {
                for k in 1...max(1, Int(24 * 3600 / step)) { starts.append(now.addingTimeInterval(Double(k) * step)) }
            }
        }
        var entries: [WidgetSnapshot] = []
        for start in starts {
            guard let slot = slot(at: start) else { continue }
            let day = LocalDate(start, calendar: calendar)
            let base = WidgetSnapshot(
                date: start, slotStart: slot.start, card: slot.card, state: slot.state, mode: mode,
                phase: mode == .selfTest ? .question : .answer, quizOptions: slot.quizOptions,
                quizAnswer: slot.quizAnswer, reviewedToday: reviewed(on: day), dailyTarget: dailyTarget
            )
            if mode == .selfTest {
                let reveal = slot.start.addingTimeInterval(revealDelay)
                if reveal <= start {
                    var answer = base
                    answer.phase = .answer
                    entries.append(answer)
                } else {
                    entries.append(base)
                    var answer = base
                    answer.date = reveal
                    answer.phase = .answer
                    entries.append(answer)
                }
            } else {
                entries.append(base)
            }
        }
        return entries
    }

    // MARK: - Watch actions (applied on the watch at once, then on the phone)

    public mutating func apply(_ action: WatchAction) {
        switch action {
        case .markKnown(let id):
            setState(.learned, for: id)
        case .markStruggling(let id):
            setState(.struggling, for: id)
        case .answer(let id, let option, let slotStart):
            guard let i = slots.firstIndex(where: { $0.start == slotStart && $0.card.id == id }),
                  slots[i].quizAnswer == nil else { return }
            slots[i].quizAnswer = option
            if option != slots[i].card.word { setState(.struggling, for: id) }
            reviewedToday += 1
        case .practice(let id, let correct):
            if !correct { setState(.struggling, for: id) }
            reviewedToday += 1
        }
    }

    /// The day's words for the watch's mini review, each once, in slot order.
    public var practiceSlots: [Slot] {
        var seen: Set<String> = []
        return slots.filter { seen.insert($0.card.id).inserted }
    }

    private mutating func setState(_ state: LearningState, for id: String) {
        for i in slots.indices where slots[i].card.id == id { slots[i].state = state }
    }

    // MARK: - Transport

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) throws -> WatchPayload { try JSONDecoder().decode(WatchPayload.self, from: data) }
}

/// A tap on the watch, sent to the phone, which records it like a widget button.
public enum WatchAction: Codable, Sendable, Equatable {
    case markKnown(cardID: String)
    case markStruggling(cardID: String)
    case answer(cardID: String, option: String, slotStart: Date)
    /// An answer in the watch's mini review (not tied to the widget slot).
    case practice(cardID: String, correct: Bool)

    /// Records the action in the phone's database.
    public func perform(db: Database, clock: AppClock) throws {
        switch self {
        case .markKnown(let id):
            try WidgetActions.markKnown(cardID: id, db: db, clock: clock)
        case .markStruggling(let id):
            try WidgetActions.markStruggling(cardID: id, db: db, clock: clock)
        case .answer(let id, let option, let slotStart):
            try WidgetActions.answerQuiz(cardID: id, option: option, slotStart: slotStart, db: db, clock: clock)
        case .practice(let id, let correct):
            try LearningStore.record(.answered(correct: correct), cardID: id, source: .widget, clock: clock, db: db)
        }
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) throws -> WatchAction { try JSONDecoder().decode(WatchAction.self, from: data) }
}

/// The latest payload, stored in the watch's App Group container so the watch app and its
/// complications read the same file.
public enum WatchPayloadStore {
    static let fileName = "watch-payload.json"

    public static func url() throws -> URL {
        try AppConfig.sharedContainerURL().appendingPathComponent(fileName)
    }

    public static func load() -> WatchPayload? {
        guard let url = try? url(), let data = try? Data(contentsOf: url) else { return nil }
        return try? WatchPayload.decode(data)
    }

    public static func save(_ payload: WatchPayload) throws {
        try payload.encoded().write(to: try url(), options: .atomic)
    }
}

/// Dictionary keys used over WatchConnectivity.
public enum WatchKeys {
    public static let payload = "payload"
    public static let action = "action"
}
