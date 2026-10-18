import Foundation
import KelimeCore
import Observation
import WatchConnectivity
import WatchKit
import WidgetKit

/// The watch side of the iPhone link. Holds the latest payload, keeps it in the App Group for
/// the complications, and sends taps back to the phone.
@MainActor
@Observable
final class WatchSession: NSObject {
    static let shared = WatchSession()

    private(set) var payload: WatchPayload? = WatchPayloadStore.load()

    func start() {
        guard WCSession.isSupported(), WCSession.default.delegate == nil else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Records a tap here at once, then queues it for the phone. `transferUserInfo` survives
    /// the phone being away and is delivered in order.
    func send(_ action: WatchAction) {
        payload?.apply(action)
        persist()
        guard let data = try? action.encoded() else { return }
        WCSession.default.transferUserInfo([WatchKeys.action: data])
    }

    fileprivate func receive(_ data: Data) {
        guard let new = try? WatchPayload.decode(data) else { return }
        // A context sent before our latest taps reached the phone would undo them.
        if let payload, new.generatedAt < payload.generatedAt { return }
        payload = new
        persist()
    }

    private func persist() {
        if let payload { try? WatchPayloadStore.save(payload) }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard let data = session.receivedApplicationContext[WatchKeys.payload] as? Data else { return }
        Task { @MainActor in self.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchKeys.payload] as? Data else { return }
        Task { @MainActor in self.receive(data) }
    }

    /// Complication updates from the phone arrive as user info.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchKeys.payload] as? Data else { return }
        Task { @MainActor in self.receive(data) }
    }
}

/// Lets the system wake the app in the background when the phone sends new words, so the
/// complications update without opening the app.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        Task { @MainActor in WatchSession.shared.start() }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let connectivity = task as? WKWatchConnectivityRefreshBackgroundTask {
                Task { @MainActor in
                    WatchSession.shared.start()
                    // Keep the task open until the pending data has been delivered.
                    for _ in 0..<20 where WCSession.default.hasContentPending {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                    connectivity.setTaskCompletedWithSnapshot(false)
                }
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
