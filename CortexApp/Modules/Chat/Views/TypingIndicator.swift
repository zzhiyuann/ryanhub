import SwiftUI

/// Animated typing indicator (three bouncing dots) shown when waiting for a response.
struct TypingIndicator: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animating = false

    private let dotSize: CGFloat = 8
    private let animationDuration: Double = 0.5

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Bot avatar
            Text("🐱")
                .font(.system(size: 24))
                .frame(width: 32, height: 32)

            // Dots
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AdaptiveColors.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
            )

            Spacer(minLength: 60)
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
