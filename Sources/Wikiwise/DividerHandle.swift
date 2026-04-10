import SwiftUI
import AppKit

/// Invisible resizable divider between sidebar and detail.
/// Blends with sidebar color, shows indicator on hover, resize cursor on mouseover.
struct DividerHandle: View {
    @Binding var sidebarWidth: CGFloat
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        ZStack {
            // Background matches sidebar
            Color.sidebarBg

            // Subtle indicator on hover/drag
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.sidebarRule)
                .frame(width: 3)
                .opacity(isDragging ? 0.8 : isHovering ? 0.5 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .animation(.easeInOut(duration: 0.1), value: isDragging)
        }
        .frame(width: 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartWidth = sidebarWidth
                    }
                    let new = dragStartWidth + value.translation.width
                    sidebarWidth = max(160, min(400, new))
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}
