import SwiftUI

struct URLCardView: View {
    let urlString: String

    private var host: String {
        URL(string: urlString)?.host ?? urlString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "link")
                .font(.title2)
                .foregroundStyle(.blue)
            Text(host)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
            Text(urlString)
                .font(.system(size: 9))
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(
            width: Constants.cardWidth,
            height: Constants.cardHeight,
            alignment: .topLeading
        )
    }
}
