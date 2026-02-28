import SwiftUI

/// Reusable circular Bo avatar using the actual cat photo from app assets.
/// Use this wherever Bo's identity needs to be displayed (chat bubbles,
/// timeline rows, headers, etc.) instead of generic SF Symbols or emoji.
struct BoAvatar: View {
    let size: CGFloat

    init(size: CGFloat = 30) {
        self.size = size
    }

    var body: some View {
        Image("BoAvatar")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 12) {
        BoAvatar(size: 24)
        BoAvatar(size: 30)
        BoAvatar(size: 40)
    }
    .padding()
}
