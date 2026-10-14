import Foundation
import KelimeCore
import Observation

/// App-wide state. Owns startup: the database opens and content imports off the main actor,
/// while the launch screen shows progress. A failure surfaces the step name instead of freezing.
@MainActor
@Observable
final class AppModel {
    enum Phase {
        case launching(step: StartupStep, progress: Double)
        case failed(StartupError)
        case ready(AppDatabase)
    }

    private(set) var phase: Phase = .launching(step: .openDatabase, progress: 0)

    var database: AppDatabase? {
        if case .ready(let db) = phase { db } else { nil }
    }

    /// Called when the app comes to the foreground.
    func becameActive() async {
        if let database { await WidgetRefresher.refresh(database) }
    }

    func start() async {
        if case .ready = phase { return }
        phase = .launching(step: .openDatabase, progress: 0)
        let contentURL = Bundle.main.url(forResource: "cards", withExtension: "json", subdirectory: "Content")
        do {
            let db = try await AppBootstrap.run(contentURL: contentURL, progress: { step, progress in
                Task { @MainActor [weak self] in
                    guard let self, case .launching = self.phase else { return }
                    self.phase = .launching(step: step, progress: progress)
                }
            })
            phase = .ready(db)
            await WidgetRefresher.refresh(db)
        } catch {
            phase = .failed(error)
        }
    }
}
