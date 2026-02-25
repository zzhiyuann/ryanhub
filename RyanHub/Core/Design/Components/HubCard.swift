import SwiftUI

/// A standard card container with Ryan Hub design system styling.
/// Uses hubSurface background, rounded corners (16pt), and a subtle shadow.
struct HubCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        HubCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(.hubHeading)
                Text("Card description goes here.")
                    .font(.hubBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
