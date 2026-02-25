import SwiftUI

/// Renders a single chat message bubble with role-based styling.
/// User messages: right-aligned, cortexPrimary background, white text.
/// Assistant messages: left-aligned, cortexSurface background, with cat avatar.
struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            } else {
                // Bot avatar
                Text("🐱")
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Message content
                if isUser {
                    Text(message.content)
                        .font(.cortexBody)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.cortexPrimary)
                        )
                } else {
                    MarkdownContent(text: message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AdaptiveColors.surface(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
                        )
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Markdown Content

/// Simple markdown renderer supporting bold, code blocks, inline code, and lists.
private struct MarkdownContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        // Use SwiftUI's built-in Markdown support in Text for basic formatting
        Text(markdownAttributedString)
            .font(.cortexBody)
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            .textSelection(.enabled)
    }

    private var markdownAttributedString: AttributedString {
        (try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(text)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: .user("Hello, how are you?"))
        MessageBubble(message: .assistant("I'm doing great! Here's some **bold** text and `code`."))
        MessageBubble(message: .assistant("Let me help you with that.", isStreaming: true))
    }
    .padding()
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
