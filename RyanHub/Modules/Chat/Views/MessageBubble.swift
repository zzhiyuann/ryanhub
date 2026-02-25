import SwiftUI

/// Renders a single chat message bubble with Telegram-like styling.
/// User messages: right-aligned, hubPrimary background, white text with tail.
/// Assistant messages: left-aligned, surface background, with cat avatar and tail.
struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser {
                Spacer(minLength: 48)
            } else {
                // Bot avatar
                Text("\u{1F431}")
                    .font(.system(size: 22))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(AdaptiveColors.surface(for: colorScheme))
                    )
                    .offset(y: -2)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                // Message content bubble
                bubbleContent
                    .background(bubbleBackground)
                    .clipShape(BubbleShape(isUser: isUser))

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                    .padding(.horizontal, 4)
            }

            if !isUser {
                Spacer(minLength: 48)
            }
        }
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.messageType {
        case .image:
            imageBubbleContent
        case .voice:
            voiceBubbleContent
        case .text:
            textBubbleContent
        }
    }

    @ViewBuilder
    private var textBubbleContent: some View {
        if isUser {
            Text(message.content)
                .font(.hubBody)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .textSelection(.enabled)
        } else {
            MarkdownContent(text: message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var imageBubbleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let base64 = message.imageBase64,
               let data = Data(base64Encoded: base64),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 220, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(4)
            } else {
                // Placeholder for images that were stripped from persistence
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                    Text(message.content.isEmpty ? "[Image]" : message.content)
                        .font(.hubBody)
                }
                .foregroundStyle(isUser ? .white : AdaptiveColors.textSecondary(for: colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            if !message.content.isEmpty, message.imageBase64 != nil {
                Text(message.content)
                    .font(.hubCaption)
                    .foregroundStyle(isUser ? .white.opacity(0.9) : AdaptiveColors.textPrimary(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private var voiceBubbleContent: some View {
        HStack(spacing: 8) {
            // Play icon
            Image(systemName: "waveform")
                .font(.system(size: 18))
                .foregroundStyle(isUser ? .white.opacity(0.9) : Color.hubPrimary)

            // Waveform bars
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    let height = waveformHeight(for: index)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isUser ? Color.white.opacity(0.6) : Color.hubPrimary.opacity(0.5))
                        .frame(width: 2.5, height: height)
                }
            }
            .frame(height: 24)

            // Duration
            if let duration = message.voiceDuration {
                Text(formatDuration(duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isUser ? .white.opacity(0.8) : AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Background

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            Color.hubPrimary
        } else {
            AdaptiveColors.surface(for: colorScheme)
                .overlay(
                    BubbleShape(isUser: false)
                        .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Helpers

    /// Generate pseudo-random waveform bar heights for visual effect.
    private func waveformHeight(for index: Int) -> CGFloat {
        let hash = abs(message.id.hashValue &+ index)
        let normalized = CGFloat(hash % 100) / 100.0
        return 4 + normalized * 20
    }

    /// Format duration as m:ss.
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Bubble Shape with Tail

/// A bubble shape with a small tail on one side, similar to Telegram.
struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isUser {
            // User bubble: tail on bottom-right
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            // Tail
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius - tailSize),
                radius: radius, startAngle: .degrees(0), endAngle: .degrees(45), clockwise: false
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX + tailSize - 2, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY - 4)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX - 4, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
            )
        } else {
            // Assistant bubble: tail on bottom-left
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            // Tail
            path.addQuadCurve(
                to: CGPoint(x: rect.minX - tailSize + 2, y: rect.maxY),
                control: CGPoint(x: rect.minX + 4, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius - tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY - 4)
            )
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius - tailSize),
                radius: radius, startAngle: .degrees(135), endAngle: .degrees(180), clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Markdown Content

/// Simple markdown renderer supporting bold, code blocks, inline code, and lists.
private struct MarkdownContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Text(markdownAttributedString)
            .font(.hubBody)
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
