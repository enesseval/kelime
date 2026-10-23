import Foundation
import KelimeCore
import Observation
import SwiftUI

enum AppTab: Hashable {
    case today, play, words, settings
}

/// Screens pushed onto a tab's navigation stack.
enum Route: Hashable {
    case word(String)
    case puzzleArchive
    case widgetMode
    case widgetLog
    case usageCounters
    case unit(String)
    case story(String, String)
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
    var settingsPath: [Route] = []
    var paywall: PaywallRequest?
    /// Presents a Quick Review session full screen.
    var reviewPresented = false
    /// Presents a crossword full screen.
    var puzzle: PuzzleRequest?
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
        default:
            tab = .today
            todayPath.append(.word(id))
        }
    }

    /// Opens a Quick Review session. Quick Review is unlimited.
    func startQuickReview() {
        UsageCounter.count(.quickReview)
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
        paywall = PaywallRequest(trigger: trigger, deck: deck)
    }

    /// Handles `kelime://word/<id>` and `kelime://puzzle` from widgets.
    func handle(_ url: URL) {
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
        case "puzzle":
            tab = .play
            playPath = []
            openPuzzle()
        default:
            break
        }
    }
}
