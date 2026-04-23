import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Query(sort: \ClipboardItem.createdAt, order: .reverse)
    private var recentItems: [ClipboardItem]

    let clipboardManager: ClipboardManager
    let onOpenPanel: () -> Void

    private var displayItems: [ClipboardItem] {
        Array(recentItems.prefix(10))
    }

    var body: some View {
        // Open the full floating panel
        Button("Show Clipyy Panel") {
            onOpenPanel()
        }
        .keyboardShortcut("z", modifiers: [.command, .shift])

        Divider()

        // Recent clipboard items
        if displayItems.isEmpty {
            Text("No items yet")
        } else {
            ForEach(displayItems, id: \.id) { item in
                Button(action: {
                    clipboardManager.copyToClipboard(item)
                }) {
                    Label(
                        String(item.plainText.prefix(60)),
                        systemImage: item.itemType.iconName
                    )
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Clipyy") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
