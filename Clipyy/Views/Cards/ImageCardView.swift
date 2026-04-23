import SwiftUI
import AppKit

struct ImageCardView: View {
    let imageData: Data

    var body: some View {
        if let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.cardWidth, height: Constants.cardHeight)
                .clipped()
        } else {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: Constants.cardWidth, height: Constants.cardHeight)
        }
    }
}
