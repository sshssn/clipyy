import SwiftUI
import SwiftData

// MARK: - Keyboard Navigator

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

private struct PanelLayout {
    let flat: [ClipboardItem]
    let pageItems: [ClipboardItem]
    let grouped: [(group: DateGroup, items: [ClipboardItem])]
    let indexMap: [PersistentIdentifier: Int]
    let totalPages: Int
    let categoryCounts: [ContentCategory: Int]
    let totalFilteredCount: Int

    init(allItems: [ClipboardItem], searchText: String, pinnedOnly: Bool,
         selectedCategory: ContentCategory?, page: Int, pageSize: Int) {
        var baseFiltered = allItems
        if pinnedOnly {
            baseFiltered = baseFiltered.filter { $0.isPinned }
        }
        if !searchText.isEmpty {
            baseFiltered = baseFiltered.filter {
                $0.plainText.localizedCaseInsensitiveContains(searchText)
            }
        }

        self.totalFilteredCount = baseFiltered.count

        var counts: [ContentCategory: Int] = [:]
        for item in baseFiltered {
            counts[item.category, default: 0] += 1
        }
        self.categoryCounts = counts

        var items = baseFiltered
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        self.flat = items

        let ps = max(1, pageSize)
        self.totalPages = max(1, (items.count + ps - 1) / ps)
        let clampedPage = max(0, min(page, totalPages - 1))
        let pageSlice = Array(items.dropFirst(clampedPage * ps).prefix(ps))
        self.pageItems = pageSlice

        self.grouped = pageSlice.groupedByDate()

        var map: [PersistentIdentifier: Int] = [:]
        map.reserveCapacity(pageSlice.count)
        for (i, item) in pageSlice.enumerated() {
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
    @State private var selectedCategory: ContentCategory? = nil
    @State private var currentPage = 0
    @State private var expandedItemID: PersistentIdentifier? = nil
    @State private var revealedSensitiveIDs: Set<PersistentIdentifier> = []

    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void

    private var layout: PanelLayout {
        PanelLayout(
            allItems: allItems,
            searchText: searchText,
            pinnedOnly: showPinnedOnly,
            selectedCategory: selectedCategory,
            page: currentPage,
            pageSize: Constants.itemsPerPage
        )
    }

    var body: some View {
        let data = layout

        VStack(spacing: 0) {
            toolbarArea

            categoryTabBar(data: data)

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
                                        isExpanded: expandedItemID == item.id,
                                        isSensitiveRevealed: revealedSensitiveIDs.contains(item.id),
                                        onCopy: {
                                            pasteItem(item)
                                        },
                                        onTogglePin: {
                                            item.isPinned.toggle()
                                            try? modelContext.save()
                                        },
                                        onDelete: {
                                            clipboardManager.deleteItem(item)
                                        },
                                        onToggleExpand: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                expandedItemID = expandedItemID == item.id ? nil : item.id
                                            }
                                        },
                                        onToggleReveal: {
                                            if revealedSensitiveIDs.contains(item.id) {
                                                revealedSensitiveIDs.remove(item.id)
                                            } else {
                                                revealedSensitiveIDs.insert(item.id)
                                            }
                                        },
                                        onSetCategory: { newCategory in
                                            item.category = newCategory
                                            try? modelContext.save()
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: navigator.selectedIndex) { _, newIndex in
                        guard newIndex >= 0, newIndex < data.pageItems.count else { return }
                        proxy.scrollTo(data.pageItems[newIndex].id, anchor: .center)
                    }
                }
            }

            if data.totalPages > 1 {
                Divider()
                paginationFooter(data: data)
            }
        }
        .frame(width: Constants.panelWidth, height: Constants.panelHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            navigator.itemCount = data.pageItems.count
            navigator.onDismiss = { [onDismiss] in onDismiss() }
            navigator.onPasteIndex = { [weak clipboardManager] index in
                let currentLayout = self.layout
                guard index >= 0, index < currentLayout.pageItems.count,
                      let manager = clipboardManager else { return }
                onDismiss()
                manager.copyAndPaste(currentLayout.pageItems[index])
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
            currentPage = 0
            updateNavigatorCount()
        }
        .onChange(of: showPinnedOnly) { _, _ in
            navigator.selectedIndex = 0
            currentPage = 0
            updateNavigatorCount()
        }
        .onChange(of: selectedCategory) { _, _ in
            navigator.selectedIndex = 0
            currentPage = 0
            updateNavigatorCount()
        }
        .onChange(of: currentPage) { _, _ in
            navigator.selectedIndex = 0
            updateNavigatorCount()
        }
    }

    private func updateNavigatorCount() {
        let count = layout.pageItems.count
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

    // MARK: - Category Tab Bar

    private func categoryTabBar(data: PanelLayout) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CategoryTab(
                    icon: "tray.full",
                    label: "All",
                    count: data.totalFilteredCount,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(ContentCategory.allCases, id: \.self) { cat in
                    let count = data.categoryCounts[cat] ?? 0
                    CategoryTab(
                        icon: cat.iconName,
                        label: cat.label,
                        count: count,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                    .opacity(count > 0 ? 1.0 : 0.45)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
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

    // MARK: - Pagination Footer

    private func paginationFooter(data: PanelLayout) -> some View {
        HStack(spacing: 12) {
            Button {
                currentPage = max(0, currentPage - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            .foregroundStyle(currentPage == 0 ? .quaternary : .secondary)

            Text("Page \(currentPage + 1) of \(data.totalPages)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                currentPage = min(data.totalPages - 1, currentPage + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= data.totalPages - 1)
            .foregroundStyle(currentPage >= data.totalPages - 1 ? .quaternary : .secondary)

            Spacer()

            Text("\(data.flat.count) items")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

// MARK: - Category Tab

private struct CategoryTab: View {
    let icon: String
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    let isExpanded: Bool
    let isSensitiveRevealed: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onToggleExpand: () -> Void
    let onToggleReveal: () -> Void
    let onSetCategory: (ContentCategory) -> Void

    @State private var isHovering = false

    private var isLongContent: Bool {
        item.plainText.count > 100
    }

    private var isSensitive: Bool {
        item.category == .sensitive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: item.itemType.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    contentPreview
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        categoryBadge

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

                HStack(spacing: 2) {
                    if isSensitive {
                        Image(systemName: isSensitiveRevealed ? "eye.fill" : "eye.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(isSensitiveRevealed ? .orange : .secondary.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                            .onTapGesture { onToggleReveal() }
                            .help(isSensitiveRevealed ? "Hide" : "Reveal")
                    }

                    if isLongContent {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                            .onTapGesture { onToggleExpand() }
                            .help(isExpanded ? "Collapse" : "Expand")
                    }

                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundStyle(item.isPinned ? .orange : .secondary.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .onTapGesture { onTogglePin() }
                        .help(item.isPinned ? "Unpin" : "Pin")
                }
            }

            if isExpanded && isLongContent {
                expandedContent
            }
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
            if isSensitive {
                Button(isSensitiveRevealed ? "Hide Content" : "Reveal Content") { onToggleReveal() }
            }
            if isLongContent {
                Button(isExpanded ? "Collapse" : "Expand Full Content") { onToggleExpand() }
            }
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            if item.itemType != .image {
                Divider()
                Menu("Set Category") {
                    ForEach(ContentCategory.allCases.filter { $0 != .image }, id: \.self) { cat in
                        Button {
                            onSetCategory(cat)
                        } label: {
                            HStack {
                                Label(cat.label, systemImage: cat.iconName)
                                if item.category == cat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder
    private var categoryBadge: some View {
        if item.category != .text {
            Text(item.category.label)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(categoryColor.opacity(0.15))
                .foregroundStyle(categoryColor)
                .clipShape(Capsule())
        }
    }

    private var categoryColor: Color {
        switch item.category {
        case .code:      return .blue
        case .link:      return .purple
        case .image:     return .green
        case .sensitive: return .red
        case .file:      return .orange
        case .text:      return .gray
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.itemType {
        case .image:
            HStack(spacing: 6) {
                if let thumbData = item.thumbnailData, let nsImage = NSImage(data: thumbData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else if let data = item.imageData, let nsImage = NSImage(data: data) {
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
            VStack(alignment: .leading, spacing: 2) {
                if isSensitive && !isSensitiveRevealed {
                    Text(maskedText(item.plainText))
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                } else {
                    Text(item.plainText)
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }

                if isLongContent {
                    Text(formatCharCount(item.plainText.count))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.horizontal, 10)

            ScrollView {
                Text(isSensitive && !isSensitiveRevealed
                     ? maskedText(item.plainText)
                     : (item.textContent ?? item.plainText))
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 44)
            }
            .frame(maxHeight: 200)

            HStack {
                Spacer()
                Text("\(item.plainText.count) characters")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .padding(.trailing, 10)
            }
            .padding(.bottom, 4)
        }
    }

    private func maskedText(_ text: String) -> String {
        let visibleCount = min(8, text.count / 4)
        let prefix = String(text.prefix(visibleCount))
        let dotsCount = min(20, max(4, text.count - visibleCount))
        return prefix + String(repeating: "\u{2022}", count: dotsCount)
    }

    private func formatCharCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM chars", Double(count) / 1_000_000.0)
        }
        if count >= 1000 {
            return String(format: "%.1fK chars", Double(count) / 1000.0)
        }
        return "\(count) chars"
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
