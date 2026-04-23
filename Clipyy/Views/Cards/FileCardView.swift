import SwiftUI

struct FileCardView: View {
    let filePath: String

    private var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    private var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.uppercased()
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "doc.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(fileName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if !fileExtension.isEmpty {
                Text(fileExtension)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(width: Constants.cardWidth, height: Constants.cardHeight)
    }
}
