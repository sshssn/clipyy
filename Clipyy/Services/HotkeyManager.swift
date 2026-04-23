import Foundation
import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onToggle: (() -> Void)?

    func register() {
        // Global monitor: fires when app is NOT focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when app IS focused
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Cmd + Shift + V
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.command, .shift] && event.keyCode == UInt16(kVK_ANSI_V) {
            onToggle?()
        }
    }
}
