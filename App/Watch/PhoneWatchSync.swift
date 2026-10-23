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

    /// The watch app is not shipped for now (it is not embedded in the iPhone app), so the
    /// link stays off. Turn this on together with "Embed Watch Content" to bring it back.
    static let isEnabled = false

    private var database: AppDatabase?
    private var lastComplicationPush: Date?
    /// The payload (minus its timestamp) last sent to the complication, so an unchanged payload does not spend a push.
    private var lastComplicationSlots: Data?
    /// A push held back by the spacing below; it goes out when the spacing allows, so the
    /// latest words always reach the face.
    private var pendingComplicationPush: Task<Void, Never>?
    /// Complication pushes wake the watch to redraw the face; iOS allows about 50 a day.
    /// While plenty are left they go out a minute apart, so a tap on the phone shows on the
    /// wrist right away; when few are left they are spaced out to last the day.
    private static func complicationInterval(remaining: Int) -> TimeInterval {
        remaining > 20 ? 60 : 25 * 60
    }

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func start(database: AppDatabase) {
        guard Self.isEnabled else { return }
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
        pushComplication(data, session: session)
    }

    /// Complication user info wakes the watch and redraws the face. It goes out only when the
    /// words changed; inside the spacing window it is sent at the end of the window instead of
    /// being dropped (a dropped push left the face on yesterday's list).
    private func pushComplication(_ data: Data, session: WCSession) {
        let remaining = session.remainingComplicationUserInfoTransfers
        guard session.isComplicationEnabled, remaining > 0 else { return }
        // Everything the face shows, without the timestamp.
        let slots = (try? WatchPayload.decode(data)).flatMap { payload -> Data? in
            var payload = payload
            payload.generatedAt = .distantPast
            return try? payload.encoded()
        }
        if let slots, slots == lastComplicationSlots { return }
        let wait = lastComplicationPush.map { Self.complicationInterval(remaining: remaining) - Date().timeIntervalSince($0) } ?? 0
        if wait > 0 {
            guard pendingComplicationPush == nil else { return }
            pendingComplicationPush = Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard let self else { return }
                self.pendingComplicationPush = nil
                await self.push()
            }
            return
        }
        session.transferCurrentComplicationUserInfo([WatchKeys.payload: data])
        lastComplicationPush = Date()
        lastComplicationSlots = slots
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
