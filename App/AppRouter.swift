import Foundation
import KelimeCore
import Observation
import SwiftUI

enum AppTab: Hashable {
    case today, play, words, discover, settings
}

/// Screens pushed onto a tab's navigation stack.
enum Route: Hashable {
    case word(String)
    case puzzleArchive
    case widgetMode
    case rotation
    case widgetLog
    case usageCounters
    case unit(String)
    case userList(String)
    case story(String, String)
    case sharedList(String)
    case paywallGallery
    case streak
}

/// The games that open full screen from Oyna.
enum GameKind: String, Identifiable {
    case wordSearch, match
    var id: String { rawValue }
}

struct PuzzleRequest: Identifiable {
    let source: PuzzleSource
    var id: String {
        switch source {
        case .daily(let day): "daily-\(day.string)"
        case .personal: "personal"
        }
    }
}

/// Tab selection, per-tab navigation paths, sheets and deep links.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .today
    var todayPath: [Route] = []
    var playPath: [Route] = []
    var wordsPath: [Route] = []
    var discoverPath: [Route] = []
    var settingsPath: [Route] = []
    var paywall: PaywallRequest?
    /// Debug screenshots of a paywall design (`-paywallDesign wordCard`).
    var designPreview: PaywallDesign?
    /// Presents a Quick Review session full screen.
    var reviewPresented = false
    /// The deck of the presented Quick Review, for the exam plan; nil uses the widget's sources.
    var reviewDeck: DeckID?
    /// Presents a crossword full screen.
    var puzzle: PuzzleRequest?
    /// Presents a game full screen.
    var game: GameKind?
    /// Presents last week's summary.
    var weeklySummaryPresented = false
    /// A good moment happened inside a full-screen round; ask for the reminder once it closes.
    var reminderAskPending = false
    var reminderAskPresented = false
    /// The learner has studied on enough days; offer Pro once the round closes.
    var paywallMomentPending = false

    /// A full-screen round (Quick Review, crossword or game) is on screen.
    var roundOpen: Bool { reviewPresented || puzzle != nil || game != nil }

    /// Another sheet is up; a new one would be refused.
    var sheetShown: Bool { paywall != nil || weeklySummaryPresented || reminderAskPresented }
    /// Set by `openLists`; Kelimelerim shows Listeler and clears it.
    var listsRequested = false

    struct PaywallRequest: Identifiable {
        let trigger: PaywallTrigger
        var deck: DeckID?
        var id: String { trigger.rawValue + (deck?.rawValue ?? "") }
    }

    /// Kelimelerim › Listeler, e.g. from Bugün's "Widget'ında" line.
    func openLists() {
        tab = .words
        wordsPath = []
        listsRequested = true
    }

    func openWord(_ id: String) {
        UsageCounter.count(.wordDetail)
        switch tab {
        case .words: wordsPath.append(.word(id))
        case .play: playPath.append(.word(id))
        case .discover: discoverPath.append(.word(id))
        default:
            tab = .today
            todayPath.append(.word(id))
        }
    }

    /// Opens a Quick Review session. Quick Review is unlimited.
    func startQuickReview(deck: DeckID? = nil) {
        UsageCounter.count(.quickReview)
        reviewDeck = deck
        reviewPresented = true
    }

    /// Opens a daily crossword (today by default).
    func openPuzzle(day: LocalDate = AppClock.system.today) {
        UsageCounter.count(.puzzle)
        puzzle = PuzzleRequest(source: .daily(day))
    }

    /// The personal puzzle. Not shown for now: it returns with Pro.
    func openPersonalPuzzle() {
        puzzle = PuzzleRequest(source: .personal)
    }

    /// The puzzle archive. Not shown for now: it returns with Pro.
    func openArchive() {
        tab = .play
        playPath.append(.puzzleArchive)
    }

    func showPaywall(_ trigger: PaywallTrigger, deck: DeckID? = nil) {
        UsageCounter.count(.paywallShown, parameters: UsageSignal.paywallShown(trigger).parameters)
        PaywallMoment.noteShown(trigger)
        paywall = PaywallRequest(trigger: trigger, deck: deck)
    }

    /// A shared list from Keşfet or a link.
    func openSharedList(_ id: String) {
        tab = .discover
        discoverPath = [.sharedList(id)]
    }

    /// Handles `kelime://word/<id>` and `kelime://puzzle` from widgets, `kelime://list/<id>` and
    /// the web link `…/liste.html?id=<id>` for shared lists.
    func handle(_ url: URL) {
        if url.scheme == "https", url.path().hasSuffix("liste.html"),
           let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value {
            openSharedList(id.lowercased())
            return
        }
        guard url.scheme == "kelime" else { return }
        paywall = nil
        reviewPresented = false
        puzzle = nil
        switch url.host() {
        case "word":
            let id = url.lastPathComponent
            guard !id.isEmpty, id != "/" else { return }
            tab = .today
            todayPath = [.word(id)]
        case "list":
            let id = url.lastPathComponent
            guard UUID(uuidString: id) != nil else { return }
            openSharedList(id.lowercased())
        case "puzzle":
            tab = .play
            playPath = []
            openPuzzle()
        case "review":
            // Control Center and widget buttons: straight into a Quick Review round.
            if url.query?.contains("from=control") == true { Analytics.signal("control.quickReview") }
            tab = .today
            startQuickReview()
        case "game":
            tab = .play
            playPath = []
            game = GameKind(rawValue: url.lastPathComponent)
        default:
            break
        }
    }
}
