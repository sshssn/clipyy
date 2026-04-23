import SwiftUI
import SwiftData

// MARK: - Keyboard Navigator

/// Handles arrow key / Return / Escape via NSEvent local monitor.
/// SwiftUI's .onKeyPress doesn't work on a non-activating NSPanel,
/// so we intercept key events at the AppKit level instead.
@Observable
final class PanelNavigator {
    var selectedIndex = 0
    var itemCount = 0
    private var monitor: Any?

    var onPasteIndex: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    func startMonitoring() {
        stopMonitoring()
        selectedIndex = 0
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKey(event) ?? event
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        // Allow text input through to search field, but intercept nav keys
        let isTextField = NSApp.keyWindow?.firstResponder is NSTextView

        switch event.keyCode {
        case 126: // Up arrow
            if selectedIndex > 0 { selectedIndex -= 1 }
            return nil
        case 125: // Down arrow
            if selectedIndex < itemCount - 1 { selectedIndex += 1 }
            return nil
        case 36: // Return
            onPasteIndex?(selectedIndex)
            return nil
        case 53: // Escape
            onDismiss?()
            return nil
        default:
            return isTextField ? event : nil
        }
    }
}

// MARK: - Precomputed layout data

/// Holds the result of a single filter + group pass so it isn't recomputed
/// multiple times per body evaluation.
private struct PanelLayout {
    let flat: [ClipboardItem]
    let grouped: [(group: DateGroup, items: [ClipboardItem])]
    let indexMap: [PersistentIdentifier: Int] // O(1) index lookup

    init(allItems: [ClipboardItem], searchText: String, pinnedOnly: Bool) {
        var items = allItems

        if pinnedOnly {
            items = items.filter { $0.isPinned }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.plainText.localizedCaseInsensitiveContains(searchText)
            }
        }

        self.flat = items
        self.grouped = items.groupedByDate()

        var map: [PersistentIdentifier: Int] = [:]
        map.reserveCapacity(items.count)
        for (i, item) in items.enumerated() {
            map[item.id] = i
        }
        self.indexMap = map
    }
}

// MARK: - Panel View

struct ClipboardPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.createdAt, order: .reverse)
    private var allItems: [ClipboardItem]

    @State private var searchText = ""
    @State private var showPinnedOnly = false
    @State private var navigator = PanelNavigator()

    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void

    /// Single computation per render pass.
    private var layout: PanelLayout {
        PanelLayout(allItems: allItems, searchText: searchText, pinnedOnly: showPinnedOnly)
    }

    var body: some View {
        let data = layout // evaluate once

        VStack(spacing: 0) {
            toolbarArea

            Divider()

            if data.grouped.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(data.grouped, id: \.group.title) { section in
                                DateSectionHeader(title: section.group.title)

                                ForEach(section.items, id: \.id) { item in
                                    let idx = data.indexMap[item.id] ?? 0
                                    ClipboardListRow(
                                        item: item,
                                        isSelected: idx == navigator.selectedIndex,
                                        onCopy: {
                                            pasteItem(item)
                                        },
                                        onTogglePin: {
                                            item.isPinned.toggle()
                                            try? modelContext.save()
                                        },
                                        onDelete: {
                                            clipboardManager.deleteItem(item)
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: navigator.selectedIndex) { _, newIndex in
                        guard newIndex >= 0, newIndex < data.flat.count else { return }
                        proxy.scrollTo(data.flat[newIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: Constants.panelWidth, height: Constants.panelHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            navigator.itemCount = data.flat.count
            navigator.onDismiss = { [onDismiss] in onDismiss() }
            // Paste callback reads layout.flat at call-time via self
            navigator.onPasteIndex = { [weak clipboardManager] index in
                let currentLayout = self.layout
                guard index >= 0, index < currentLayout.flat.count,
                      let manager = clipboardManager else { return }
                onDismiss()
                manager.copyAndPaste(currentLayout.flat[index])
            }
            navigator.startMonitoring()
        }
        .onDisappear {
            navigator.stopMonitoring()
        }
        .onChange(of: allItems.count) { _, _ in
            updateNavigatorCount()
        }
        .onChange(of: searchText) { _, _ in
            navigator.selectedIndex = 0
            updateNavigatorCount()
        }
        .onChange(of: showPinnedOnly) { _, _ in
            navigator.selectedIndex = 0
            updateNavigatorCount()
        }
    }

    private func updateNavigatorCount() {
        let count = layout.flat.count
        navigator.itemCount = count
        if navigator.selectedIndex >= count {
            navigator.selectedIndex = max(0, count - 1)
        }
    }

    // MARK: - Actions

    private func pasteItem(_ item: ClipboardItem) {
        onDismiss()
        clipboardManager.copyAndPaste(item)
    }

    // MARK: - Toolbar

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

    // MARK: - Empty State

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

// MARK: - Selection Highlight

struct SelectionHighlightModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: Constants.rowCornerRadius)
                    .strokeBorder(Color.accentColor, lineWidth: isSelected ? 1.5 : 0)
                    .opacity(isSelected ? 1 : 0)
            )
    }
}

// MARK: - List Row

struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: item.itemType.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                contentPreview
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { onCopy() }

            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(item.isPinned ? .orange : .secondary.opacity(0.5))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .onTapGesture { onTogglePin() }
                .help(item.isPinned ? "Unpin" : "Pin")
        }
        .background(
            RoundedRectangle(cornerRadius: Constants.rowCornerRadius)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovering ? Color.white.opacity(0.08) : Color.white.opacity(0.03)))
        )
        .modifier(SelectionHighlightModifier(isSelected: isSelected))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy & Paste") { onCopy() }
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
