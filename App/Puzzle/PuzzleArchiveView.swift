import KelimeCore
import KelimeUI
import SwiftUI

/// Pro archive: past daily puzzles with their completion state.
struct PuzzleArchiveView: View {
    @Environment(AppModel.self) private var app
    @State private var rows: [Row] = []

    struct Row: Identifiable, Sendable {
        var day: LocalDate
        var level: CEFRLevel
        var solved: Int
        var total: Int
        var completed: Bool
        var id: String { day.string }
    }

    var body: some View {
        List(rows) { row in
            Button { app.router.openPuzzle(day: row.day) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TurkishDate.header(row.day.startDate(in: app.clock.calendar)))
                            .font(KelimeFont.ui(16, weight: .semibold, relativeTo: .body))
                        Text("\(row.level.rawValue) · \(row.solved)/\(row.total) kelime")
                            .font(KelimeFont.ui(13, relativeTo: .footnote))
                            .foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    if row.completed {
                        Text("✓").font(KelimeFont.ui(16, weight: .bold)).foregroundStyle(Palette.greenInk)
                    }
                }
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 50)
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Arşiv")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: app.dataVersion) {
            let clock = app.clock
            rows = await app.read { db -> [Row] in
                let prefs = try Preferences.load(db)
                return try (1...30).compactMap { offset -> Row? in
                    let day = clock.today.adding(days: -offset)
                    guard let (level, puzzle) = PuzzleLibrary.daily(for: prefs.level, on: day) else { return nil }
                    let saved = try PuzzleStore.load(key: DailyPuzzle.key(level: level, day: day), puzzle: puzzle, db: db)
                    return Row(day: day, level: level, solved: saved.game.solvedCount, total: puzzle.entries.count, completed: saved.completedAt != nil)
                }
            } ?? []
        }
    }
}
