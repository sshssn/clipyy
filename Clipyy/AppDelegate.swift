import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide app from Dock - run as accessory (menu bar only)
        NSApp.setActivationPolicy(.accessory)
    }
}
