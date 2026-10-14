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
}

/// Tab selection, per-tab navigation paths, sheets and deep links.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .today
    var todayPath: [Route] = []
    var playPath: [Route] = []
    var wordsPath: [Route] = []
    var paywall: PaywallRequest?
    /// Presents a Quick Review session full screen.
    var reviewPresented = false

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

    /// Opens today's crossword (milestone 6; for now the Oyna hub).
    func openPuzzle() {
        tab = .play
    }

    func showPaywall(_ trigger: PaywallTrigger, deck: DeckID? = nil) {
        paywall = PaywallRequest(trigger: trigger, deck: deck)
    }

    /// Handles `kelime://word/<id>` and `kelime://puzzle` from widgets.
    func handle(_ url: URL) {
        guard url.scheme == "kelime" else { return }
        paywall = nil
        reviewPresented = false
        switch url.host() {
        case "word":
            let id = url.lastPathComponent
            guard !id.isEmpty, id != "/" else { return }
            tab = .today
            todayPath = [.word(id)]
        case "puzzle":
            tab = .play
            playPath = []
        default:
            break
        }
    }
}
