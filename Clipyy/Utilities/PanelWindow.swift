import AppKit
import SwiftUI

// MARK: - Silent Hosting View

/// NSHostingView subclass that suppresses system beep sounds.
/// When SwiftUI gesture recognizers handle taps, the underlying NSEvents
/// can still propagate through the AppKit responder chain. If no AppKit
/// responder claims them, `noResponder(for:)` fires NSBeep(). This
/// override silences that at the hosting view level.
class SilentHostingView<Content: View>: NSHostingView<Content> {
    override func noResponder(for eventSelector: Selector) {}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Floating Panel

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    // Suppress system sounds from this panel.
    // Key input is handled by PanelNavigator's NSEvent local monitor.
    override func keyDown(with event: NSEvent) {}
    override func noResponder(for eventSelector: Selector) {}

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }
}
