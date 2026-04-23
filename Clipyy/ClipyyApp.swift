import SwiftUI
import SwiftData

@main
struct ClipyyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var clipboardManager: ClipboardManager
    @State private var panelController: PanelWindowController
    @State private var hotkeyManager: HotkeyManager

    private let modelContainer: ModelContainer

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

            // Start clipboard monitoring immediately at launch
            manager.startMonitoring()

            // Set up and register the global hotkey at launch
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
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                clipboardManager: clipboardManager,
                onOpenPanel: { togglePanel() }
            )
            .modelContainer(modelContainer)
        } label: {
            Image(systemName: "clipboard")
        }
        .menuBarExtraStyle(.window)

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
