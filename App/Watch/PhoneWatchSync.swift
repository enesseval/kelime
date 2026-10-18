import Foundation
import KelimeCore
import WatchConnectivity
import WidgetKit

/// The iPhone side of the Apple Watch link.
///
/// After every change the app sends the watch the widget's next 24 hours as application
/// context (the latest value wins, delivered when the watch can take it). When a Kelime
/// complication is on the watch face, the payload also goes as complication user info, which
/// wakes the watch to refresh it (iOS allows about 50 of these a day). Taps on the watch come
/// back as user info and are recorded like widget buttons.
@MainActor
final class PhoneWatchSync: NSObject {
    static let shared = PhoneWatchSync()

    private var database: AppDatabase?
    private var lastComplicationPush: Date?
    /// Complication pushes wake the watch to redraw the face; iOS allows about 50 a day.
    /// While plenty are left they go out a minute apart, so a tap on the phone shows on the
    /// wrist right away; when few are left they are spaced out to last the day.
    private static func complicationInterval(remaining: Int) -> TimeInterval {
        remaining > 20 ? 60 : 25 * 60
    }

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func start(database: AppDatabase) {
        self.database = database
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends the current payload, if a watch with the app is paired.
    func push() async {
        guard let database, let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled
        else { return }
        let data: Data
        do {
            data = try await database.writer.write { db in
                var rng = SystemRandomNumberGenerator()
                return try WatchPayload.make(db: db, clock: .system, using: &rng).encoded()
            }
        } catch {
            return
        }
        try? session.updateApplicationContext([WatchKeys.payload: data])
        // The watch app is open: deliver now instead of waiting for the context.
        if session.isReachable {
            session.sendMessage([WatchKeys.payload: data], replyHandler: nil, errorHandler: nil)
        }
        let remaining = session.remainingComplicationUserInfoTransfers
        if session.isComplicationEnabled, remaining > 0,
           lastComplicationPush.map({ Date().timeIntervalSince($0) > Self.complicationInterval(remaining: remaining) }) ?? true {
            session.transferCurrentComplicationUserInfo([WatchKeys.payload: data])
            lastComplicationPush = Date()
        }
    }

    private func handle(_ actionData: Data) async {
        guard let database, let action = try? WatchAction.decode(actionData) else { return }
        try? await database.writer.write { db in try action.perform(db: db, clock: .system) }
        WidgetCenter.shared.reloadAllTimelines()
        await push()
    }
}

extension PhoneWatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in await self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Switching to another paired watch: activate again for the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in await self.push() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchKeys.action] as? Data else { return }
        Task { @MainActor in await self.handle(data) }
    }
}
