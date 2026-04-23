import Foundation
import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // Static reference so the C callback can reach us
    nonisolated(unsafe) private static var shared: HotkeyManager?

    var onToggle: (() -> Void)?

    func register() {
        HotkeyManager.shared = self

        // Define the event we care about: hot key pressed
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install a Carbon event handler on the application target
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, inEvent, _ -> OSStatus in
                // Verify it's our hot key
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    inEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr, hotKeyID.id == 1 else { return OSStatus(eventNotHandledErr) }

                DispatchQueue.main.async {
                    HotkeyManager.shared?.onToggle?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // Register Cmd+Shift+Z as a system-wide hotkey
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x434C5059), // "CLPY"
            id: 1
        )
        let modifiers = UInt32(cmdKey | shiftKey)

        RegisterEventHotKey(
            UInt32(kVK_ANSI_Z),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
