import SwiftUI

/// Animated typing indicator (three bouncing dots) shown when waiting for a response.
/// Matches the assistant bubble style with avatar.
struct TypingIndicator: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animating = false

    private let dotSize: CGFloat = 7
    private let animationDuration: Double = 0.5

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Bot avatar — Facai's actual photo (matches MessageBubble style)
            FacaiAvatar(size: 30)
                .offset(y: -2)

            // Dots bubble
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: animating ? -4 : 4)
                        .animation(
                            .easeInOut(duration: animationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                BubbleShape(isUser: false)
                    .fill(AdaptiveColors.surface(for: colorScheme))
            )
            .overlay(
                BubbleShape(isUser: false)
                    .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
            )

            Spacer(minLength: 48)
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    TypingIndicator()
        .padding()
        .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
