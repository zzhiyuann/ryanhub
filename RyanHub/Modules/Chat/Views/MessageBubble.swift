import SwiftUI

/// Renders a single chat message bubble with Telegram-like styling.
/// User messages: right-aligned, hubPrimary background, white text with tail.
/// Assistant messages: left-aligned, surface background, with cat avatar and tail.
struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: ChatMessage
    /// All messages in the conversation, used to look up quoted messages for scroll.
    var allMessages: [ChatMessage] = []
    /// Per-message status (sending → acknowledged → processing → done).
    var messageStatus: ChatViewModel.MessageStatus?
    var onReply: ((ChatMessage) -> Void)?
    var onScrollToMessage: ((String) -> Void)?
    var onRetry: ((ChatMessage) -> Void)?
    /// Called when the user edits a message: (originalMessage, newContent).
    var onEdit: ((ChatMessage, String) -> Void)?

    private var isUser: Bool { message.role == .user }
    @State private var swipeOffset: CGFloat = 0
    @State private var showFullScreenImage = false
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser {
                // Reply icon appears on swipe
                if swipeOffset < -30 {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.hubPrimary.opacity(0.7))
                        .transition(.scale.combined(with: .opacity))
                }
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
                // Quoted message preview
                if let replyPreview = message.replyToPreview {
                    quotedPreview(replyPreview)
                }

                // Message content bubble (or inline edit field)
                if isEditing {
                    editBubble
                } else {
                    bubbleContent
                        .background(bubbleBackground)
                        .clipShape(BubbleShape(isUser: isUser))
                }

                // Timestamp + status + edit button
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))

                    if isUser, let status = messageStatus {
                        messageStatusIcon(status)
                    }

                    // Edit button: visible for all user text messages
                    if isUser && !isEditing && message.messageType == .text {
                        Button {
                            editText = message.content
                            withAnimation(.easeOut(duration: 0.15)) {
                                isEditing = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.hubPrimary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 4)

                // Retry button for failed user messages
                if case .failed = messageStatus, isUser {
                    Button {
                        onRetry?(message)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                            Text("Retry")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.hubAccentRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .stroke(Color.hubAccentRed.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .offset(x: swipeOffset)

            if !isUser {
                Spacer(minLength: 48)
                // Reply icon appears on swipe
                if swipeOffset > 30 {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.hubPrimary.opacity(0.7))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let drag = value.translation.width
                    // User messages: swipe left (negative). Assistant: swipe right (positive).
                    if isUser && drag < 0 {
                        swipeOffset = max(drag, -60)
                    } else if !isUser && drag > 0 {
                        swipeOffset = min(drag, 60)
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 40
                    if (isUser && value.translation.width < -threshold) ||
                       (!isUser && value.translation.width > threshold) {
                        onReply?(message)
                    }
                    withAnimation(.spring(response: 0.3)) {
                        swipeOffset = 0
                    }
                }
        )
        .animation(.interactiveSpring, value: swipeOffset)
    }

    // MARK: - Quoted Preview

    @ViewBuilder
    private func quotedPreview(_ preview: String) -> some View {
        Button {
            if let replyId = message.replyToId {
                onScrollToMessage?(replyId)
            }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.hubPrimary)
                    .frame(width: 3, height: 16)

                Text(preview)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isUser
                            ? Color.white.opacity(0.7)
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isUser
                            ? Color.white.opacity(0.15)
                            : AdaptiveColors.surfaceSecondary(for: colorScheme)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit Bubble

    @ViewBuilder
    private var editBubble: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("Edit message...", text: $editText, axis: .vertical)
                .font(.hubBody)
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(1...8)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.hubPrimary.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isEditing = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)

                Button {
                    let newContent = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !newContent.isEmpty, newContent != message.content else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isEditing = false
                        }
                        return
                    }
                    onEdit?(message, newContent)
                    withAnimation(.easeOut(duration: 0.15)) {
                        isEditing = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Save")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.hubPrimary)
                    )
                }
                .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 4) {
                if !message.content.isEmpty {
                    MarkdownContent(text: message.content)
                }
                if message.isStreaming {
                    InlineTypingDots()
                }
            }
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
                Button {
                    showFullScreenImage = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(4)
                .fullScreenCover(isPresented: $showFullScreenImage) {
                    FullScreenImageViewer(image: uiImage)
                }
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

    // MARK: - Message Status Icon

    @ViewBuilder
    private func messageStatusIcon(_ status: ChatViewModel.MessageStatus) -> some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 9))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
        case .acknowledged:
            Text("\u{1F440}")
                .font(.system(size: 10))
        case .processing:
            Image(systemName: "ellipsis")
                .font(.system(size: 9))
                .foregroundStyle(Color.hubPrimary.opacity(0.7))
                .symbolEffect(.variableColor.iterative, isActive: true)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.hubAccentGreen.opacity(0.8))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.hubAccentRed)
        }
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

// MARK: - Inline Typing Dots

/// Small bouncing dots shown inside a streaming message bubble.
private struct InlineTypingDots: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animating = false

    private let dotSize: CGFloat = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AdaptiveColors.textSecondary(for: colorScheme))
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: animating ? -3 : 3)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.top, 2)
        .onAppear { animating = true }
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
            .fixedSize(horizontal: false, vertical: true)
    }

    private var markdownAttributedString: AttributedString {
        // Use full markdown parsing so block-level elements (lists, headings,
        // code blocks, paragraphs) render correctly instead of being collapsed
        // into a single inline span that gets truncated.
        (try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(text)
    }
}

// MARK: - Full Screen Image Viewer

/// Zoomable full-screen image viewer presented as a sheet.
struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = lastScale * value.magnification
                        }
                        .onEnded { _ in
                            lastScale = max(scale, 1.0)
                            if scale < 1.0 {
                                withAnimation(.spring(response: 0.3)) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                        .simultaneously(with:
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    } else {
                                        // Drag down to dismiss
                                        offset = CGSize(width: 0, height: max(0, value.translation.height))
                                    }
                                }
                                .onEnded { value in
                                    if scale <= 1.0 && value.translation.height > 100 {
                                        dismiss()
                                    } else {
                                        lastOffset = offset
                                        if scale <= 1.0 {
                                            withAnimation(.spring(response: 0.3)) {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                                }
                        )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 3.0
                            lastScale = 3.0
                        }
                    }
                }
        }
        .onTapGesture {
            dismiss()
        }
        .statusBarHidden()
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
