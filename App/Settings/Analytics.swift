import Foundation
import KelimeCore
import TelemetryDeck

/// Anonymous usage signals through TelemetryDeck: which features are used and whether people
/// add the widget, never who they are. TelemetryDeck hashes its device id and keeps no IP
/// addresses; Debug builds send nothing and TestFlight builds are marked as test data.
enum Analytics {
    static let appID = "E70DAA36-B891-49C0-9F68-3DBD35E8643C"
    static let namespace = "com.kelimewidget"

    /// Call once at launch.
    static func start() {
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID, namespace: namespace))
    }

    /// Sends `event` as a signal, e.g. "Usage.listCreated", with optional parameters
    /// (`paywallShown` has `source`, `purchase` has `kind` and `product`).
    static func send(_ event: UsageCounter, parameters: [String: String] = [:]) {
        TelemetryDeck.signal("Usage.\(String(describing: event))", parameters: parameters)
    }

    /// Sends a rule-built signal (see `UsageSignal`).
    static func send(_ signal: UsageSignal) {
        TelemetryDeck.signal(signal.name, parameters: signal.parameters)
    }

    /// A named signal with parameters, e.g. `signal("game.match.finished", ["score": "12"])`.
    static func signal(_ name: String, _ parameters: [String: String] = [:]) {
        TelemetryDeck.signal(name, parameters: parameters)
    }
}
