import Foundation
import GRDB

/// Applies learning events to the shared database. Used by the app and the widget's App Intents.
public enum LearningStore {
    /// Current progress for a card; a missing row is a new card.
    public static func state(of cardID: String, db: Database) throws -> CardState {
        try CardState.fetchOne(db, key: cardID) ?? CardState(cardID: cardID)
    }

    /// Records `event` for `cardID` and returns the new state.
    ///
    /// Answers also get a `review_log` row (for weekly stats and the free daily limit);
    /// hints and the Biliyorum / Zorlanıyorum buttons do not.
    @discardableResult
    public static func record(
        _ event: LearningEvent,
        cardID: String,
        source: ReviewSource,
        clock: AppClock,
        sessionID: String? = nil,
        db: Database
    ) throws -> CardState {
        let now = clock.now
        let today = LocalDate(now, calendar: clock.calendar)
        let next = LearningRules.apply(event, to: try state(of: cardID, db: db), on: today)
        try next.save(db)

        if case .answered(let correct) = event {
            var log = ReviewLog(cardID: cardID, answeredAt: now, answeredOn: today, correct: correct, source: source, sessionID: sessionID)
            try log.insert(db)
        }
        return next
    }

    public static func setFavorite(_ favorite: Bool, cardID: String, db: Database) throws {
        var current = try state(of: cardID, db: db)
        current.favorite = favorite
        try current.save(db)
    }
}
