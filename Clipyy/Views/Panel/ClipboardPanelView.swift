import SwiftUI
import SwiftData

struct ClipboardPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.createdAt, order: .reverse)
    private var allItems: [ClipboardItem]

    @State private var searchText = ""
    @State private var showPinnedOnly = false

    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void

    private var filteredItems: [ClipboardItem] {
        var items = allItems

        if showPinnedOnly {
            items = items.filter { $0.isPinned }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.plainText.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    private var groupedItems: [(group: DateGroup, items: [ClipboardItem])] {
        filteredItems.groupedByDate()
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarArea

            Divider()

            if groupedItems.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(groupedItems, id: \.group.title) { section in
                            DateSectionHeader(title: section.group.title)

                            ForEach(section.items, id: \.id) { item in
                                ClipboardListRow(
                                    item: item,
                                    onCopy: {
                                        onDismiss()
                                        clipboardManager.copyAndPaste(item)
                                    },
                                    onCopyPlainText: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(item.plainText, forType: .string)
                                        onDismiss()
                                    },
                                    onTogglePin: {
                                        item.isPinned.toggle()
                                        try? modelContext.save()
                                    },
                                    onDelete: {
                                        clipboardManager.deleteItem(item)
                                    }
                                )
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: Constants.panelWidth, height: Constants.panelHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var toolbarArea: some View {
        HStack(spacing: 12) {
            SearchBarView(text: $searchText)

            Spacer()

            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    Button {
                        showPinnedOnly = false
                    } label: {
                        Image(systemName: "clock")
                            .foregroundStyle(!showPinnedOnly ? .primary : .secondary)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help("All History")

                    Button {
                        showPinnedOnly.toggle()
                    } label: {
                        Image(systemName: "pin")
                            .foregroundStyle(showPinnedOnly ? .primary : .secondary)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help("Pinned Items")

                    Button {
                        clipboardManager.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help("Clear History")

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help("Close Panel")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No clipboard items yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Row

struct ClipboardListRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onCopyPlainText: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                // Type icon
                Image(systemName: item.itemType.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                // Content preview
                contentPreview
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Metadata
                VStack(alignment: .trailing, spacing: 2) {
                    if let appName = item.sourceAppName {
                        Text(appName)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.createdAt.shortRelative)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }

                // Pin indicator
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: Constants.rowCornerRadius))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Constants.rowCornerRadius)
                .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.white.opacity(0.05))
        )
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") { onCopy() }
            Button("Copy as Plain Text") { onCopyPlainText() }
            Divider()
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.itemType {
        case .image:
            HStack(spacing: 6) {
                if let data = item.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("Image")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        case .color:
            HStack(spacing: 6) {
                let hex = item.textContent ?? ""
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 16, height: 16)
                Text(hex)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        default:
            Text(item.plainText)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Hex Color Helper

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
