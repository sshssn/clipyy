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
        // If the user is typing in the search field, let the text field handle it
        if let responder = NSApp.keyWindow?.firstResponder,
           responder is NSTextView {
            // Only intercept Escape and arrow keys from search field
            switch event.keyCode {
            case 53: // Escape
                onDismiss?()
                return nil
            case 126: // Up arrow
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 125: // Down arrow
                if selectedIndex < itemCount - 1 { selectedIndex += 1 }
                return nil
            case 36: // Return
                onPasteIndex?(selectedIndex)
                return nil
            default:
                return event
            }
        }

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
            return event
        }
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

    private var flatItems: [ClipboardItem] {
        filteredItems
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
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(groupedItems, id: \.group.title) { section in
                                DateSectionHeader(title: section.group.title)

                                ForEach(section.items, id: \.id) { item in
                                    let itemIndex = flatItems.firstIndex(where: { $0.id == item.id }) ?? 0
                                    ClipboardListRow(
                                        item: item,
                                        isSelected: itemIndex == navigator.selectedIndex,
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
                        guard newIndex >= 0, newIndex < flatItems.count else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(flatItems[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: Constants.panelWidth, height: Constants.panelHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            let items = flatItems
            navigator.itemCount = items.count
            navigator.onDismiss = { [onDismiss] in onDismiss() }
            navigator.onPasteIndex = { index in
                guard index >= 0, index < items.count else { return }
                self.pasteItem(items[index])
            }
            navigator.startMonitoring()
        }
        .onDisappear {
            navigator.stopMonitoring()
        }
        .onChange(of: flatItems.count) { _, newCount in
            navigator.itemCount = newCount
            if navigator.selectedIndex >= newCount {
                navigator.selectedIndex = max(0, newCount - 1)
            }
            // Update the paste callback so it uses the latest items
            let items = flatItems
            navigator.onPasteIndex = { index in
                guard index >= 0, index < items.count else { return }
                self.pasteItem(items[index])
            }
        }
        .onChange(of: searchText) { _, _ in
            navigator.selectedIndex = 0
        }
        .onChange(of: showPinnedOnly) { _, _ in
            navigator.selectedIndex = 0
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

// MARK: - Animated RGB Border

struct RGBBorderModifier: ViewModifier {
    let isSelected: Bool
    @State private var phase: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: Constants.rowCornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center,
                            angle: .degrees(phase)
                        ),
                        lineWidth: isSelected ? 2 : 0
                    )
                    .opacity(isSelected ? 1 : 0)
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .onChange(of: isSelected) { _, selected in
                if selected {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        phase = 360
                    }
                } else {
                    phase = 0
                }
            }
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
            // Main row — click to paste
            Button(action: onCopy) {
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
            }
            .buttonStyle(.plain)

            // Pin button
            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(item.isPinned ? .orange : .secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin")
        }
        .background(
            RoundedRectangle(cornerRadius: Constants.rowCornerRadius)
                .fill(isHovering ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .modifier(RGBBorderModifier(isSelected: isSelected))
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
