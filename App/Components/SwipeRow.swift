import KelimeUI
import SwiftUI

/// A row that slides left to reveal small round action buttons.
///
/// Each row is a horizontal paging scroll view, so the system tells horizontal swipes from
/// vertical page scrolls (a DragGesture on the row blocked the page from scrolling). The row
/// reads and sets its state through `scrollPosition`: with a trailing anchor the position is
/// "actions" when the buttons are showing and "content" when closed. Which row is open lives
/// in `openRow`; opening one closes the others.
struct SwipeRow<Content: View>: View {
    struct Action: Identifiable {
        let title: String
        let systemImage: String
        let ink: Color
        let background: Color
        let run: () -> Void
        var id: String { title }
    }

    private enum Part: Hashable {
        case content, actions
    }

    let id: String
    let actions: [Action]
    @Binding var openRow: String?
    let onTap: () -> Void
    @ViewBuilder let content: Content

    @State private var position: Part? = .content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                content
                    .containerRelativeFrame(.horizontal)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if openRow != nil { openRow = nil } else { onTap() }
                    }
                    .id(Part.content)

                HStack(spacing: 12) {
                    ForEach(actions) { action in
                        Button {
                            action.run()
                            openRow = nil
                        } label: {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(action.ink)
                                .frame(width: 38, height: 38)
                                .background(action.background, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(action.title)
                        // Grows from small as the row opens instead of sliding in at full size.
                        .scrollTransition(.interactive, axis: .horizontal) { button, phase in
                            button
                                .scaleEffect(phase.isIdentity ? 1 : 0.3)
                                .opacity(phase.isIdentity ? 1 : 0)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 20)
                .frame(maxHeight: .infinity)
                .id(Part.actions)
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        // The row slides past the page margin instead of being cut flat at it.
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .trailing)
        .onChange(of: position) { _, part in
            if part == .actions {
                openRow = id
            } else if openRow == id {
                openRow = nil
            }
        }
        .onChange(of: openRow) { _, current in
            if current != id, position == .actions {
                withAnimation(.snappy(duration: 0.25)) { position = .content }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityActions {
            ForEach(actions) { action in
                Button(action.title, action: action.run)
            }
        }
    }
}
