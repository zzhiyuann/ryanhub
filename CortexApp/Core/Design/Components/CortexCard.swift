import SwiftUI

/// A standard card container with Cortex design system styling.
/// Uses cortexSurface background, rounded corners (16pt), and a subtle shadow.
struct CortexCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(CortexLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: CortexLayout.cardCornerRadius)
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
        CortexCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(.cortexHeading)
                Text("Card description goes here.")
                    .font(.cortexBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
