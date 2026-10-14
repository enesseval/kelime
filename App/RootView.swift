import KelimeCore
import KelimeUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.phase {
        case .launching(let step, let progress):
            LaunchView(step: step, progress: progress)
        case .failed(let error):
            StartupErrorView(error: error) {
                Task { await model.start() }
            }
        case .ready:
            MainTabView()
        }
    }
}

private struct LaunchView: View {
    let step: StartupStep
    let progress: Double

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .tint(Palette.accent)
                .frame(maxWidth: 200)
            Text(step.title)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

private struct StartupErrorView: View {
    let error: StartupError
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uygulama açılamadı")
                .font(.title2.weight(.semibold))
            Text("Adım: \(error.step.title)")
                .font(.headline)
            Text(error.message)
                .font(.footnote.monospaced())
                .foregroundStyle(Palette.ink2)
                .textSelection(.enabled)
            Button("Tekrar dene", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
    }
}
