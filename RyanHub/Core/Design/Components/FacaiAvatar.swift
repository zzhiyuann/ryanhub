import SwiftUI

/// Reusable circular Facai avatar using the actual cat photo from app assets.
/// Use this wherever Facai's identity needs to be displayed (chat bubbles,
/// timeline rows, headers, etc.) instead of generic SF Symbols or emoji.
struct FacaiAvatar: View {
    let size: CGFloat

    init(size: CGFloat = 30) {
        self.size = size
    }

    var body: some View {
        Image("FacaiAvatar")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 12) {
        FacaiAvatar(size: 24)
        FacaiAvatar(size: 30)
        FacaiAvatar(size: 40)
    }
    .padding()
}
