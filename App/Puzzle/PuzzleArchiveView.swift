import KelimeCore
import KelimeUI
import SwiftUI

/// Archive (free: two puzzles a week; Pro and the trial: all): past daily puzzles with their completion state.
struct PuzzleArchiveView: View {
    @Environment(AppModel.self) private var app
    @State private var rows: [Row] = []
    @State private var remaining = ArchiveQuota.freePerWeek

    struct Row: Identifiable, Sendable {
        var day: LocalDate
        var level: CEFRLevel
        var solved: Int
        var total: Int
        var completed: Bool
        var id: String { day.string }
    }

    var body: some View {
        List {
            if !app.isPro {
                VStack(alignment: .leading, spacing: 4) {
                    Text(remaining > 0 ? "Bu hafta \(remaining) bulmaca hakkın var" : "Bu haftaki \(ArchiveQuota.freePerWeek) hakkın bitti")
                        .font(KelimeFont.ui(15, weight: .semibold, relativeTo: .body))
                    Text("Haftada \(ArchiveQuota.freePerWeek) bulmaca ücretsiz, pazartesi yenilenir. Oynadığın bulmacayı tekrar açmak hak harcamaz. Pro ile hepsi açık.")
                        .font(KelimeFont.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.ink2)
                }
                .listRowBackground(Palette.accentSoft)
            }
            ForEach(rows) { row in
            Button { Task { await app.openArchivePuzzle(row.day, played: row.solved > 0) } } label: {
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
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Arşiv")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: app.dataVersion) {
            let clock = app.clock
            remaining = await app.read { db in try ArchiveQuota.remaining(today: clock.today, db: db) } ?? ArchiveQuota.freePerWeek
            rows = await app.read { db -> [Row] in
                let prefs = try Preferences.load(db)
                return try (1...30).compactMap { offset -> Row? in
                    let day = clock.today.adding(days: -offset)
                    guard let (level, puzzle) = try PuzzleLibrary.daily(for: prefs.level, on: day, db: db) else { return nil }
                    let saved = try PuzzleStore.load(key: DailyPuzzle.key(level: level, day: day), puzzle: puzzle, db: db)
                    return Row(day: day, level: level, solved: saved.game.solvedCount, total: puzzle.entries.count, completed: saved.completedAt != nil)
                }
            } ?? []
        }
    }
}
