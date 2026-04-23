import SwiftUI

struct ClipboardRowView: View {
    let items: [ClipboardItem]
    let onSelect: (ClipboardItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Constants.cardSpacing) {
                ForEach(items, id: \.id) { item in
                    ClipboardCardView(item: item) {
                        onSelect(item)
                    }
                    .contextMenu {
                        Button("Copy") { onSelect(item) }
                        Button("Copy as Plain Text") {
                            copyAsPlainText(item)
                        }
                        Divider()
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            item.isPinned.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func copyAsPlainText(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.plainText, forType: .string)
    }
}
