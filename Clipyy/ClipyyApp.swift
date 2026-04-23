import SwiftUI
import SwiftData
import AppKit

@main
struct ClipyyApp: App {
    private let modelContainer: ModelContainer
    @State private var clipboardManager: ClipboardManager
    @State private var panelController: PanelWindowController
    @State private var hotkeyManager: HotkeyManager

    init() {
        let schema = Schema([ClipboardItem.self, Pinboard.self])
        let config = ModelConfiguration(
            "ClipyyStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.modelContainer = container

            let manager = ClipboardManager(modelContext: container.mainContext)
            self._clipboardManager = State(initialValue: manager)

            let panel = PanelWindowController()
            self._panelController = State(initialValue: panel)

            let hotkey = HotkeyManager()
            self._hotkeyManager = State(initialValue: hotkey)

            // Defer Timer and NSEvent registration to after the app run loop is ready.
            // Starting these in init() can interfere with MenuBarExtra setup.
            DispatchQueue.main.async {
                manager.startMonitoring()

                hotkey.onToggle = {
                    panel.toggle(
                        content: ClipboardPanelView(
                            clipboardManager: manager,
                            onDismiss: { panel.hide() }
                        )
                        .modelContainer(container)
                    )
                }
                hotkey.register()
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra("Clipyy", systemImage: "doc.on.clipboard.fill") {
            MenuBarView(
                clipboardManager: clipboardManager,
                onOpenPanel: { togglePanel() }
            )
            .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }

    private func togglePanel() {
        panelController.toggle(
            content: ClipboardPanelView(
                clipboardManager: clipboardManager,
                onDismiss: { panelController.hide() }
            )
            .modelContainer(modelContainer)
        )
    }
}
