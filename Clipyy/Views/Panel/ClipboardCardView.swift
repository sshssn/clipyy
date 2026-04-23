import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardContent
                .frame(width: Constants.cardWidth, height: Constants.cardHeight)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
                        .stroke(
                            isHovering ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .onHover { hovering in
                    isHovering = hovering
                }
                .onTapGesture {
                    onSelect()
                }

            if let appName = item.sourceAppName {
                Text(appName.prefix(1))
                    .font(.system(size: 8, weight: .bold))
                    .padding(3)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(4)
            }
        }
        .help(item.plainText.prefix(200).description)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch item.itemType {
        case .text, .rtf:
            TextCardView(text: item.textContent ?? "")
        case .image:
            ImageCardView(imageData: item.imageData ?? Data())
        case .url:
            URLCardView(urlString: item.textContent ?? "")
        case .fileURL:
            FileCardView(filePath: item.textContent ?? "")
        case .color:
            ColorCardView(hexString: item.textContent ?? "")
        case .unknown:
            Image(systemName: "questionmark.square")
                .foregroundStyle(.secondary)
        }
    }
}
