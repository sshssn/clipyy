import AppKit
import SwiftUI

final class PanelWindowController {
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<AnyView>?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show<Content: View>(content: Content) {
        if panel == nil {
            let rect = NSRect(
                x: 0, y: 0,
                width: Constants.panelWidth,
                height: Constants.panelHeight
            )
            panel = FloatingPanel(contentRect: rect)
        }

        guard let panel = panel else { return }

        let hostingView = NSHostingView(rootView: AnyView(content))
        panel.contentView = hostingView
        self.hostingView = hostingView

        // Position centered on the screen where the mouse is
        if let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSEvent.mouseLocation)
        }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - Constants.panelWidth / 2
            let y = screenFrame.midY - Constants.panelHeight / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle<Content: View>(content: @autoclosure () -> Content) {
        if isVisible {
            hide()
        } else {
            show(content: content())
        }
    }
}
