import CoreText
import Foundation
import KelimeCore
import SwiftUI
import Testing
@testable import KelimeUI

/// Renders every widget family and state to PNG so layouts can be reviewed without a device.
///
/// Rendering always runs (catching crashes and layout traps); images are written only when
/// `KELIME_RENDER_DIR` is set:
///   KELIME_RENDER_DIR=/tmp/widgets swift test --package-path Packages/KelimeCore --filter WidgetRenderTests
@MainActor
struct WidgetRenderTests {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static let fontsRegistered: Bool = {
        let dir = repoRoot.appendingPathComponent("Fonts")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return !files.isEmpty
    }()

    let outputDir: URL? = ProcessInfo.processInfo.environment["KELIME_RENDER_DIR"].map { URL(fileURLWithPath: $0) }
    let s = SampleContent.self

    enum Surface { case home, lock }

    @discardableResult
    func render<V: View>(_ name: String, _ view: V, size: CGSize, surface: Surface = .home, dark: Bool = false, background: Color = Palette.paper) throws -> CGImage {
        #expect(Self.fontsRegistered)
        let framed = Group {
            switch surface {
            case .home:
                view
                    .padding(16)
                    .frame(width: size.width, height: size.height)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            case .lock:
                view
                    .padding(size.height > 60 ? 8 : 0)
                    .frame(width: size.width, height: size.height)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: size.width == size.height ? size.width / 2 : 18, style: .continuous))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(surface == .lock ? Color(white: 0.16) : (dark ? Color(white: 0.05) : Color(white: 0.85)))
        .environment(\.colorScheme, dark ? .dark : .light)

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "\(name) did not render")
        if let outputDir {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let url = outputDir.appendingPathComponent("\(name).png")
            let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            #expect(CGImageDestinationFinalize(dest))
        }
        return image
    }

    @Test func lockScreen() throws {
        let rect = CGSize(width: 172, height: 76)
        try render("lock-inline", InlineWidgetView(entry: s.snapshot()), size: CGSize(width: 260, height: 24), surface: .lock)
        for state in LearningState.allCases {
            try render("lock-rect-card-\(state.rawValue)", RectangularWidgetView(entry: s.snapshot(state: state, mode: .card)), size: rect, surface: .lock)
        }
        try render("lock-rect-card-long", RectangularWidgetView(entry: s.snapshot(s.longest, mode: .card)), size: rect, surface: .lock)
        try render("lock-rect-sentence", RectangularWidgetView(entry: s.snapshot(mode: .sentence)), size: rect, surface: .lock)
        try render("lock-rect-dictionary", RectangularWidgetView(entry: s.snapshot(mode: .dictionary)), size: rect, surface: .lock)
        try render("lock-rect-dictionary-long", RectangularWidgetView(entry: s.snapshot(s.longest, mode: .dictionary)), size: rect, surface: .lock)
        try render("lock-rect-wordsentence", RectangularWidgetView(entry: s.snapshot(mode: .wordAndSentence)), size: rect, surface: .lock)
        try render("lock-rect-wordsentence-long", RectangularWidgetView(entry: s.snapshot(s.longest, mode: .wordAndSentence)), size: rect, surface: .lock)
        try render("lock-rect-sentence-long", RectangularWidgetView(entry: s.snapshot(s.longest, mode: .sentence)), size: rect, surface: .lock)
        try render("lock-rect-selftest-question", RectangularWidgetView(entry: s.snapshot(mode: .selfTest, phase: .question)), size: rect, surface: .lock)
        try render("lock-rect-selftest-answer", RectangularWidgetView(entry: s.snapshot(mode: .selfTest, phase: .answer)), size: rect, surface: .lock)
        try render("lock-rect-selftest-long", RectangularWidgetView(entry: s.snapshot(s.longest, mode: .selfTest, phase: .question)), size: rect, surface: .lock)
        try render("lock-rect-phrase", RectangularWidgetView(entry: s.snapshot(s.phrase, mode: .card)), size: rect, surface: .lock)
        try render("lock-rect-phrase-dictionary", RectangularWidgetView(entry: s.snapshot(s.phrase, mode: .dictionary)), size: rect, surface: .lock)
        try render("lock-inline-phrase", InlineWidgetView(entry: s.snapshot(s.phrase)), size: CGSize(width: 260, height: 24), surface: .lock)
        try render("lock-rect-empty", RectangularWidgetView(entry: .empty(at: .now)), size: rect, surface: .lock)
        try render("lock-circular", ReviewRingWidgetView(entry: s.snapshot()), size: CGSize(width: 76, height: 76), surface: .lock)
    }

    @Test(arguments: WidgetThemeID.allCases)
    func themes(_ theme: WidgetThemeID) throws {
        var entry = s.snapshot()
        entry.theme = theme
        try render("theme-\(theme.rawValue)-medium", MediumCardWidgetView(entry: entry), size: CGSize(width: 364, height: 170), background: theme.colors.background)
        try render("theme-\(theme.rawValue)-small", SmallWidgetView(entry: entry), size: CGSize(width: 170, height: 170), background: theme.colors.background)
    }

    @Test(arguments: [false, true])
    func homeScreen(dark: Bool) throws {
        let suffix = dark ? "-dark" : ""
        let small = CGSize(width: 170, height: 170)
        let medium = CGSize(width: 364, height: 170)
        let large = CGSize(width: 364, height: 382)
        try render("small-learned\(suffix)", SmallWidgetView(entry: s.snapshot(s.reliable, state: .learned)), size: small, dark: dark)
        try render("small-long\(suffix)", SmallWidgetView(entry: s.snapshot(s.longest, state: .new)), size: small, dark: dark)
        try render("small-empty\(suffix)", SmallWidgetView(entry: .empty(at: .now)), size: small, dark: dark)
        try render("medium-card\(suffix)", MediumCardWidgetView(entry: s.snapshot()), size: medium, dark: dark)
        try render("small-phrase\(suffix)", SmallWidgetView(entry: s.snapshot(s.phrase)), size: small, dark: dark)
        try render("medium-card-phrase\(suffix)", MediumCardWidgetView(entry: s.snapshot(s.phrase)), size: medium, dark: dark)
        try render("medium-card-long\(suffix)", MediumCardWidgetView(entry: s.snapshot(s.longest)), size: medium, dark: dark)
        try render("medium-quiz\(suffix)", MediumQuizWidgetView(entry: s.snapshot()), size: medium, dark: dark)
        try render("medium-quiz-correct\(suffix)", MediumQuizWidgetView(entry: s.snapshot(quizAnswer: s.reluctant.word)), size: medium, dark: dark)
        try render("medium-quiz-wrong\(suffix)", MediumQuizWidgetView(entry: s.snapshot(quizAnswer: s.reliable.word)), size: medium, dark: dark)
        try render("large\(suffix)", LargeWidgetView(entry: s.snapshot(s.hesitate, state: .struggling)), size: large, dark: dark)
        try render("large-no-struggling\(suffix)", LargeWidgetView(entry: WidgetSnapshot(date: .now, card: s.hesitate)), size: large, dark: dark)
    }
}
