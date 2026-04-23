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
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(groupedItems, id: \.group.title) { section in
                            DateSectionHeader(title: section.group.title)
                            ClipboardRowView(items: section.items) { item in
                                clipboardManager.copyToClipboard(item)
                                onDismiss()
                            }
                        }
                    }
                    .padding(.vertical, 8)
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

            Button {
                showPinnedOnly = false
            } label: {
                Image(systemName: "clock")
                    .foregroundStyle(!showPinnedOnly ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help("All History")

            Button {
                showPinnedOnly.toggle()
            } label: {
                Image(systemName: "pin")
                    .foregroundStyle(showPinnedOnly ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help("Pinned Items")

            Button {
                clipboardManager.clearHistory()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear History")
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
