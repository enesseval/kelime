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
    case themePicker
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

    struct PaywallRequest: Identifiable {
        let trigger: PaywallTrigger
        var deck: DeckID?
        var id: String { trigger.rawValue + (deck?.rawValue ?? "") }
    }

    func openWord(_ id: String) {
        switch tab {
        case .words: wordsPath.append(.word(id))
        case .play: playPath.append(.word(id))
        default:
            tab = .today
            todayPath.append(.word(id))
        }
    }

    /// Opens a Quick Review session; the free daily limit sends free users to the paywall.
    func startQuickReview(remaining: Int?) {
        if remaining == 0 {
            showPaywall(.reviewLimit)
        } else {
            reviewPresented = true
        }
    }

    /// Opens a daily crossword (today by default).
    func openPuzzle(day: LocalDate = AppClock.system.today) {
        puzzle = PuzzleRequest(source: .daily(day))
    }

    /// The Pro personal puzzle; free users see the paywall.
    func openPersonalPuzzle(isPro: Bool) {
        if isPro {
            puzzle = PuzzleRequest(source: .personal)
        } else {
            showPaywall(.personalPuzzle)
        }
    }

    /// The Pro archive; free users see the paywall.
    func openArchive(isPro: Bool) {
        if isPro {
            tab = .play
            playPath.append(.puzzleArchive)
        } else {
            showPaywall(.archive)
        }
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
