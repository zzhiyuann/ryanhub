import SwiftUI

/// Chat input bar with text field and send button, fixed at the bottom of the chat.
struct ChatInputBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let isConnected: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AdaptiveColors.border(for: colorScheme))

            HStack(alignment: .bottom, spacing: 10) {
                // Text input
                TextField(L10n.chatPlaceholder, text: $text, axis: .vertical)
                    .font(.cortexBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isFocused ? Color.cortexPrimary.opacity(0.5) : AdaptiveColors.border(for: colorScheme),
                                lineWidth: 1
                            )
                    )
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }

                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.cortexPrimary : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                }
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, CortexLayout.standardPadding)
            .padding(.vertical, 10)
            .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputBar(text: .constant("Hello"), isConnected: true) {
            print("Send")
        }
    }
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
