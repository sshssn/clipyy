import AppKit
import SwiftUI

final class PanelWindowController {
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var clickMonitor: Any?

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
        startClickOutsideMonitor()
    }

    func hide() {
        stopClickOutsideMonitor()
        panel?.orderOut(nil)
    }

    func toggle<Content: View>(content: @autoclosure () -> Content) {
        if isVisible {
            hide()
        } else {
            show(content: content())
        }
    }

    // MARK: - Click Outside to Dismiss

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else { return }
            // Global monitor only fires for clicks OUTSIDE the app's windows,
            // so any global click means the user clicked away from the panel.
            self.hide()
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
