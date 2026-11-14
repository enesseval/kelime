import ActivityKit
import KelimeCore
import KelimeUI
import SwiftUI
import WidgetKit

/// The exam countdown on the lock screen and in the Dynamic Island (docs/V1_2_PLAN.md §5). The
/// text comes from KelimeCore's `ExamCountdownState.line`, the same rule Android's notification uses.
struct ExamCountdownActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExamCountdownAttributes.self) { context in
            ExamCountdownLockView(state: context.state)
                .activityBackgroundTint(Palette.paper)
                .activitySystemActionForegroundColor(Palette.ink)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(state.exam.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.daysLeft == 0 ? "Bugün" : "\(state.daysLeft) gün")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.line).font(.system(size: 15, weight: .medium))
                        ExamCountdownBar(state: state)
                    }
                }
            } compactLeading: {
                Text(state.exam.rawValue).font(.system(size: 13, weight: .semibold, design: .rounded))
            } compactTrailing: {
                Text(state.daysLeft == 0 ? "Bugün" : "\(state.daysLeft) g")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.accent)
            } minimal: {
                Text("\(state.daysLeft)").font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
    }
}

private struct ExamCountdownLockView: View {
    let state: ExamCountdownState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.line)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            ExamCountdownBar(state: state)
        }
        .padding(16)
    }
}

/// Today's share of the daily target, full once the target is met or the list is learned.
private struct ExamCountdownBar: View {
    let state: ExamCountdownState

    private var fraction: Double {
        state.remaining == 0 || state.dailyTarget == 0 ? 1 : min(Double(state.doneToday) / Double(state.dailyTarget), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule().fill(Palette.green).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 5)
    }
}
