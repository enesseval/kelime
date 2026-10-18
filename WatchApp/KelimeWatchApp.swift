import KelimeCore
import KelimeUI
import SwiftUI

@main
struct KelimeWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .onAppear { WatchSession.shared.start() }
        }
    }
}

/// Three vertical pages: the word on the widget now, a short review, and what comes next.
struct WatchHomeView: View {
    private var session: WatchSession { .shared }

    var body: some View {
        if let payload = session.payload {
            TimelineView(.everyMinute) { context in
                TabView {
                    if let slot = payload.slot(at: context.date) {
                        WatchWordPage(slot: slot)
                    }
                    WatchReviewPage(slots: payload.practiceSlots)
                    WatchUpcomingPage(payload: payload, now: context.date)
                }
                .tabViewStyle(.verticalPage)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.system(size: 28))
                    .foregroundStyle(Palette.ink2)
                Text("Kelimelerin iPhone'dan gelecek")
                    .font(KelimeFont.ui(15, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("iPhone'da Kelime Widget'ı bir kez aç.")
                    .font(KelimeFont.ui(13))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
