import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

// Previews for every family × mode × state. Tinted and vibrant rendering can be switched in the
// canvas; the lock-screen families always preview vibrant.

private let s = SampleContent.self

#Preview("Inline", as: .accessoryInline) {
    WordWidget()
} timeline: {
    s.snapshot()
    WidgetSnapshot.empty(at: .now)
}

#Preview("Rectangular · Kart", as: .accessoryRectangular) {
    WordWidget()
} timeline: {
    s.snapshot(state: .new, mode: .card)
    s.snapshot(state: .struggling, mode: .card)
    s.snapshot(state: .learned, mode: .card)
    s.snapshot(s.longest, mode: .card)
    WidgetSnapshot.empty(at: .now)
}

#Preview("Rectangular · Cümle", as: .accessoryRectangular) {
    WordWidget()
} timeline: {
    s.snapshot(mode: .sentence)
    s.snapshot(s.longest, mode: .sentence)
}

#Preview("Rectangular · Kendini sına", as: .accessoryRectangular) {
    WordWidget()
} timeline: {
    s.snapshot(mode: .selfTest, phase: .question)
    s.snapshot(mode: .selfTest, phase: .answer)
    s.snapshot(s.longest, mode: .selfTest, phase: .question)
}

#Preview("Circular", as: .accessoryCircular) {
    ReviewRingWidget()
} timeline: {
    WidgetSnapshot(date: .now, card: s.reluctant, reviewedToday: 0)
    WidgetSnapshot(date: .now, card: s.reluctant, reviewedToday: 7)
    WidgetSnapshot(date: .now, card: s.reluctant, reviewedToday: 12)
}

#Preview("Small", as: .systemSmall) {
    WordWidget()
} timeline: {
    s.snapshot(s.reliable, state: .learned)
    s.snapshot(s.reluctant, state: .struggling)
    s.snapshot(s.hesitate, state: .new)
    s.snapshot(s.longest, state: .new)
    WidgetSnapshot.empty(at: .now)
}

#Preview("Medium · Kart", as: .systemMedium) {
    WordWidget()
} timeline: {
    s.snapshot()
    s.snapshot(s.longest)
    WidgetSnapshot.empty(at: .now)
}

#Preview("Medium · Quiz", as: .systemMedium) {
    QuizWidget()
} timeline: {
    s.snapshot()
    s.snapshot(quizAnswer: s.reluctant.word)
    s.snapshot(quizAnswer: s.reliable.word)
    WidgetSnapshot.empty(at: .now)
}

#Preview("Large", as: .systemLarge) {
    WordWidget()
} timeline: {
    s.snapshot(s.hesitate, state: .struggling)
    WidgetSnapshot(date: .now, card: s.hesitate, state: .new)
    WidgetSnapshot.empty(at: .now)
}
