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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Clipyy")
                    .font(.headline)
                Spacer()
                Button("Open Panel") {
                    onOpenPanel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Recent items list
            if displayItems.isEmpty {
                Text("No items yet")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(displayItems, id: \.id) { item in
                            MenuBarItemRow(item: item) {
                                clipboardManager.copyToClipboard(item)
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 350)
            }

            Divider()

            // Footer
            HStack {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")),
                                     to: nil, from: nil)
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }
}

struct MenuBarItemRow: View {
    let item: ClipboardItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: item.itemType.iconName)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)

                Text(item.plainText)
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer()

                Text(item.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
