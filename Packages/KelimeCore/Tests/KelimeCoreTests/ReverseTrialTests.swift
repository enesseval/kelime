import Foundation
import GRDB
import Testing
@testable import KelimeCore

struct ReverseTrialTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let hour: TimeInterval = 3600

    func manager(_ store: MemoryTrialStore = MemoryTrialStore()) -> (ReverseTrialManager, MemoryTrialStore) {
        (ReverseTrialManager(store: store), store)
    }

    // MARK: Boundaries

    @Test func startsOnFirstLaunchAndIsOpen() {
        let (m, store) = manager()
        let first = m.refresh(now: t0)
        #expect(first.justStarted)
        #expect(first.isActive)
        #expect(first.daysLeft == 3)
        #expect(store.trial?.startedAt == t0)
        #expect(ReverseTrial.duration == 72 * 3600)
    }

    @Test func justBefore72HoursIsStillOpen() {
        let (m, _) = manager()
        m.refresh(now: t0)
        let s = m.refresh(now: t0 + 72 * hour - 1)
        #expect(s.isActive)
        #expect(!s.hasEnded)
        #expect(s.daysLeft == 1)
        #expect(!s.justEnded)
    }

    @Test func exactly72HoursAndJustAfterAreOver() {
        let (m, _) = manager()
        m.refresh(now: t0)
        let at = m.refresh(now: t0 + 72 * hour)
        #expect(!at.isActive)
        #expect(at.hasEnded)
        #expect(at.daysLeft == 0)
        #expect(at.justEnded)
        let after = m.refresh(now: t0 + 72 * hour + 1)
        #expect(!after.isActive)
        #expect(!after.justEnded)
    }

    @Test func daysLeftCountsWholeDaysRoundedUp() {
        let trial = ReverseTrial(startedAt: t0)
        #expect(trial.daysLeft(now: t0) == 3)
        #expect(trial.daysLeft(now: t0 + 1) == 3)
        #expect(trial.daysLeft(now: t0 + 24 * hour) == 2)
        #expect(trial.daysLeft(now: t0 + 24 * hour + 1) == 2)
        #expect(trial.daysLeft(now: t0 + 47 * hour) == 2)
        #expect(trial.daysLeft(now: t0 + 48 * hour) == 1)
        #expect(trial.daysLeft(now: t0 + 71 * hour) == 1)
        #expect(trial.daysLeft(now: t0 + 72 * hour) == 0)
    }

    // MARK: Clock set back, relaunch, reinstall

    @Test func settingTheClockBackDoesNotGiveMoreTime() {
        let (m, _) = manager()
        m.refresh(now: t0)
        #expect(m.refresh(now: t0 + 73 * hour).hasEnded)
        // The learner sets the clock back to day 1: still over.
        let back = m.refresh(now: t0 + 5 * hour)
        #expect(back.hasEnded)
        #expect(!back.isActive)
        #expect(back.daysLeft == 0)
    }

    @Test func clockBackDuringTheTrialDoesNotExtendIt() {
        let (m, _) = manager()
        m.refresh(now: t0)
        m.refresh(now: t0 + 60 * hour)
        // Back to hour 10, then 13 real hours later (hour 23 on the wrong clock): hour 60 is the floor.
        let s = m.refresh(now: t0 + 10 * hour)
        #expect(s.daysLeft == 1)
        #expect(s.trial!.remaining(now: s.now) == 12 * hour)
    }

    @Test func relaunchKeepsTheStartAndDoesNotStartAgain() {
        let (m1, store) = manager()
        m1.refresh(now: t0)
        let m2 = ReverseTrialManager(store: store) // a new process, the same Keychain
        let s = m2.refresh(now: t0 + 30 * hour)
        #expect(!s.justStarted)
        #expect(s.trial?.startedAt == t0)
        #expect(s.isActive)
    }

    @Test func reinstallAfterTheTrialDoesNotRestartIt() {
        let (m1, store) = manager()
        m1.refresh(now: t0)
        m1.refresh(now: t0 + 80 * hour)
        // Deleting the app keeps the Keychain item; the new install reads it.
        let s = ReverseTrialManager(store: store).refresh(now: t0 + 90 * hour)
        #expect(!s.justStarted)
        #expect(s.hasEnded)
    }

    @Test func anUnreadableStoreNeitherStartsNorGrants() {
        let (m, store) = manager()
        store.unavailable = true
        let s = m.refresh(now: t0)
        #expect(s.trial == nil)
        #expect(!s.isActive)
        #expect(!s.justStarted)
        #expect(!s.summaryDue)
        // Readable again: now it is a first launch.
        store.unavailable = false
        #expect(m.refresh(now: t0 + 1).justStarted)
    }

    @Test func startedAndEndedAreSentOnce() {
        let (m, _) = manager()
        var started = 0, ended = 0
        for offset in stride(from: 0.0, through: 100, by: 1) {
            let s = m.refresh(now: t0 + offset * hour)
            if s.justStarted { started += 1 }
            if s.justEnded { ended += 1 }
        }
        #expect(started == 1)
        #expect(ended == 1)
    }

    // MARK: Summary

    @Test func summaryIsDueOnlyAfterTheEndAndOnlyOnce() {
        let (m, _) = manager()
        #expect(!m.refresh(now: t0).summaryDue)
        #expect(!m.refresh(now: t0 + 71 * hour).summaryDue)
        #expect(m.refresh(now: t0 + 72 * hour).summaryDue)
        #expect(m.refresh(now: t0 + 100 * hour).summaryDue) // until it is shown
        m.markSummaryShown()
        #expect(!m.refresh(now: t0 + 101 * hour).summaryDue)
        // And across a relaunch.
        #expect(!ReverseTrialManager(store: m.storeForTests).refresh(now: t0 + 200 * hour).summaryDue)
    }

    @Test func usageCountsOnlyWhileTheTrialRuns() {
        let (m, store) = manager()
        m.refresh(now: t0)
        m.note(.archive, key: "2026-11-10", now: t0 + hour)
        m.note(.archive, key: "2026-11-10", now: t0 + hour) // same puzzle again: once
        m.note(.archive, key: "2026-11-11", now: t0 + 2 * hour)
        m.note(.personalPuzzle, now: t0 + 3 * hour)
        m.note(.personalPuzzle, now: t0 + 4 * hour)
        m.note(.archive, key: "2026-11-12", now: t0 + 72 * hour) // over: ignored
        #expect(store.trial?.uses(.archive) == 2)
        #expect(store.trial?.uses(.personalPuzzle) == 2)
    }

    @Test func summaryLinesListOnlyWhatWasUsedWithNumbers() {
        #expect(TrialSummary.lines(usage: [:], ownLists: 1, examPercent: 0).isEmpty)
        let lines = TrialSummary.lines(usage: ["archive": 4, "personalPuzzle": 2], ownLists: 3, examPercent: 20)
        #expect(lines == ["Arşivden 4 bulmaca", "Sana özel 2 bulmaca", "3 kendi listen", "Sınav planın %20"])
        #expect(TrialSummary.lines(usage: [:], ownLists: 1, examPercent: nil).isEmpty)
    }

    // MARK: Moment paywall

    @Test func noMomentPaywallWhilePro() {
        let now = t0
        // Everything else says "offer"; Pro (which includes the trial) says no.
        #expect(PaywallMomentRule.shouldOffer(isPro: false, studyDays: 3, offers: 0, lastOffer: nil, lastPaywall: nil, now: now))
        #expect(!PaywallMomentRule.shouldOffer(isPro: true, studyDays: 3, offers: 0, lastOffer: nil, lastPaywall: nil, now: now))
        #expect(!PaywallMomentRule.shouldOffer(isPro: false, studyDays: 2, offers: 0, lastOffer: nil, lastPaywall: nil, now: now))
        #expect(!PaywallMomentRule.shouldOffer(isPro: false, studyDays: 3, offers: 2, lastOffer: nil, lastPaywall: nil, now: now))
        #expect(!PaywallMomentRule.shouldOffer(isPro: false, studyDays: 3, offers: 1, lastOffer: now - 13 * 24 * hour, lastPaywall: nil, now: now))
        #expect(PaywallMomentRule.shouldOffer(isPro: false, studyDays: 3, offers: 1, lastOffer: now - 15 * 24 * hour, lastPaywall: nil, now: now))
        #expect(!PaywallMomentRule.shouldOffer(isPro: false, studyDays: 3, offers: 0, lastOffer: nil, lastPaywall: now - 47 * hour, now: now))
    }

    @Test func proFollowsTheTrialAndEndsWithIt() {
        // isPro = purchased || trial active, as the purchase manager computes it.
        let (m, _) = manager()
        func isPro(purchased: Bool, at offset: Double) -> Bool { purchased || m.refresh(now: t0 + offset * hour).isActive }
        #expect(isPro(purchased: false, at: 0))
        #expect(isPro(purchased: false, at: 71.99))
        #expect(!isPro(purchased: false, at: 72))
        #expect(isPro(purchased: true, at: 72))
    }
}

private extension ReverseTrialManager {
    var storeForTests: TrialStore { Mirror(reflecting: self).children.first { $0.label == "store" }!.value as! TrialStore }
}
