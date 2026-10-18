import KelimeCore
import KelimeUI
import SwiftUI

/// The word on the widget right now, with Biliyorum / Zorlanıyorum.
struct WatchWordPage: View {
    let slot: WatchPayload.Slot
    @State private var sent: LearningState?

    var body: some View {
        let card = slot.card
        let state = sent ?? slot.state
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StateDot(state, size: 8)
                    Text("\(card.level.rawValue) · \(card.pos.abbreviation)")
                        .font(KelimeFont.ui(12, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                }
                Text(card.word)
                    .font(KelimeFont.english(32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(card.meaning)
                    .font(KelimeFont.ui(16, weight: .medium))
                Text(card.exampleEN)
                    .font(KelimeFont.english(15, italic: true))
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 4)
                Text(card.exampleTR)
                    .font(KelimeFont.ui(12))
                    .foregroundStyle(Palette.ink2)
                VStack(spacing: 6) {
                    if state != .learned {
                        Button("Biliyorum") { mark(.learned) }
                            .tint(Palette.green)
                    }
                    if state != .struggling {
                        Button("Zorlanıyorum") { mark(.struggling) }
                            .tint(Palette.amber)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Şimdi")
    }

    private func mark(_ state: LearningState) {
        sent = state
        WatchSession.shared.send(state == .learned ? .markKnown(cardID: slot.card.id) : .markStruggling(cardID: slot.card.id))
        WKInterfaceDeviceHaptic.play(state == .learned ? .success : .click)
    }
}

/// A short review of today's words: the Turkish meaning, two English options.
/// After answering, a double tap (or the button) moves on.
struct WatchReviewPage: View {
    let slots: [WatchPayload.Slot]
    @State private var index = 0
    @State private var chosen: String?
    @State private var score = 0

    private static let length = 10

    var body: some View {
        let questions = Array(slots.prefix(Self.length))
        if questions.isEmpty {
            Text("Tekrar edilecek kelime yok").font(KelimeFont.ui(14))
        } else if index >= questions.count {
            VStack(spacing: 8) {
                Text("\(score)/\(questions.count)")
                    .font(KelimeFont.english(40))
                Text("Hızlı tekrar bitti").font(KelimeFont.ui(14)).foregroundStyle(Palette.ink2)
                Button("Baştan") { index = 0; score = 0; chosen = nil }
                    .primaryShortcut()
            }
        } else {
            question(questions[index], number: index + 1, total: questions.count)
        }
    }

    private func question(_ slot: WatchPayload.Slot, number: Int, total: Int) -> some View {
        let options = slot.quizOptions.isEmpty ? [slot.card.word] : slot.quizOptions
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(number)/\(total) · İngilizcesi?")
                    .font(KelimeFont.ui(12, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                Text(slot.card.meaning)
                    .font(KelimeFont.ui(17, weight: .semibold))
                ForEach(options, id: \.self) { option in
                    Button {
                        answer(option, for: slot)
                    } label: {
                        HStack {
                            Text(option).font(KelimeFont.english(19))
                            Spacer()
                            if chosen != nil && option == slot.card.word { Image(systemName: "checkmark") }
                        }
                    }
                    .tint(tint(option, slot: slot))
                    .disabled(chosen != nil)
                }
                if chosen != nil {
                    Button("Sonraki") { next() }
                        .primaryShortcut()
                        .padding(.top, 4)
                }
            }
        }
    }

    private func tint(_ option: String, slot: WatchPayload.Slot) -> Color? {
        guard let chosen else { return nil }
        if option == slot.card.word { return Palette.green }
        return option == chosen ? Palette.amber : nil
    }

    private func answer(_ option: String, for slot: WatchPayload.Slot) {
        chosen = option
        let correct = option == slot.card.word
        if correct { score += 1 }
        WatchSession.shared.send(.practice(cardID: slot.card.id, correct: correct))
        WKInterfaceDeviceHaptic.play(correct ? .success : .failure)
    }

    private func next() {
        chosen = nil
        index += 1
    }
}

/// The next words on the widget, with the time each one appears.
struct WatchUpcomingPage: View {
    let payload: WatchPayload
    let now: Date

    var body: some View {
        let upcoming = payload.slots.filter { $0.start > now }.prefix(8)
        List {
            Section {
                ForEach(Array(upcoming), id: \.start) { slot in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(slot.start.formatted(date: .omitted, time: .shortened))
                            .font(KelimeFont.ui(11, weight: .semibold))
                            .foregroundStyle(Palette.ink2)
                        Text(slot.card.word).font(KelimeFont.english(19))
                        Text(slot.card.meaning).font(KelimeFont.ui(12)).foregroundStyle(Palette.ink2)
                    }
                }
            } header: {
                Text("Sıradakiler")
            }
            Section {
                Text("Bugün \(payload.reviewed(on: LocalDate(now, calendar: .current))) / \(payload.dailyTarget) tekrar")
                    .font(KelimeFont.ui(13))
            }
        }
    }
}

private enum WKInterfaceDeviceHaptic {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

private extension View {
    /// Double tap (Apple Watch Series 9 and later, watchOS 11) triggers this button.
    @ViewBuilder
    func primaryShortcut() -> some View {
        if #available(watchOS 11, *) {
            handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}
