import SwiftUI

@main
struct KelimeWidgetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.start()
                    // A reminder tap opens a Quick Review once the app is ready.
                    appDelegate.onReminderTap = { [model] in
                        Task { await model.startQuickReview() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.becameActive() } }
                }
        }
    }
}
