import KelimeUI
import SwiftUI

/// A row that slides left to reveal round, free-standing action buttons.
///
/// Built on a horizontal paging scroll view rather than `List.swipeActions`, so the row can sit
/// on the page like any other view and the buttons can be circles. A scroll view also tells a
/// swipe from a tap: a horizontal drag never fires the row's tap.
struct SwipeRow<Content: View>: View {
    struct Action: Identifiable {
        let title: String
        let systemImage: String
        let color: Color
        let run: () -> Void
        var id: String { title }
    }

    let id: String
    let actions: [Action]
    /// The row currently open; opening one closes the others.
    @Binding var openRow: String?
    let onTap: () -> Void
    @ViewBuilder let content: Content

    @State private var isOpen = false

    private static var contentID: String { "content" }
    private static var actionsID: String { "actions" }
    private static var space: String { "swipe-row" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    Button {
                        if isOpen { close(proxy) } else { onTap() }
                    } label: {
                        content
                            .containerRelativeFrame(.horizontal)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(key: OffsetKey.self, value: geo.frame(in: .named(Self.space)).minX)
                        }
                    }
                    .id(Self.contentID)

                    HStack(spacing: 14) {
                        ForEach(actions) { action in
                            actionButton(action, proxy: proxy)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 20)
                    .id(Self.actionsID)
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: Self.space)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .onPreferenceChange(OffsetKey.self) { minX in
                let open = minX < -12
                guard open != isOpen else { return }
                isOpen = open
                if open { openRow = id }
            }
            .onChange(of: openRow) { _, current in
                if current != id && isOpen { close(proxy) }
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

    private func actionButton(_ action: Action, proxy: ScrollViewProxy) -> some View {
        Button {
            action.run()
            close(proxy)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(action.color, in: Circle())
                Text(action.title)
                    .font(KelimeFont.ui(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func close(_ proxy: ScrollViewProxy) {
        withAnimation(.snappy) { proxy.scrollTo(Self.contentID, anchor: .leading) }
        if openRow == id { openRow = nil }
    }
}

/// Leading edge of a swipe row's content inside its scroll view; below zero means open.
private struct OffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
