import SwiftUI

struct TextCardView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .frame(
                width: Constants.cardWidth - 16,
                height: Constants.cardHeight - 16,
                alignment: .topLeading
            )
            .padding(8)
    }
}
