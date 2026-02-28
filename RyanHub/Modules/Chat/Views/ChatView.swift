import SwiftUI
import PhotosUI

/// Main chat screen — the primary interaction surface for Ryan Hub.
/// Telegram-like single chat with real-time WebSocket messaging, image, and voice input.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    /// ViewModel is owned by ContentView and passed in, so it survives tab switches.
    @Bindable var viewModel: ChatViewModel
    @State private var showCamera = false
    /// The message the user is replying to (swipe-to-reply).
    @State private var replyingTo: ChatMessage?
    /// Free-text input for answering agent questions.
    @State private var questionFreeTextInput: String = ""
    /// Keyboard height for manually positioning input above the keyboard.
    @State private var keyboardHeight: CGFloat = 0
    /// Whether the user has manually scrolled up away from the bottom.
    /// When true, auto-scroll on streaming content updates is suppressed.
    @State private var userScrolledUp: Bool = false
    /// Reference to the scroll proxy, stored so keyboard handlers can trigger scroll.
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            messagesArea

            // Reply bar (shown when replying to a message)
            if let replying = replyingTo {
                replyBar(for: replying)
            }

            // Question card (shown when agent asks a question)
            if viewModel.pendingQuestion != nil {
                questionCard
            }

            // Input bar
            ChatInputBar(
                text: $viewModel.inputText,
                isConnected: viewModel.isConnected,
                isRecording: viewModel.isRecording,
                recordingDuration: viewModel.recordingDuration,
                audioLevels: viewModel.audioLevels,
                pendingImageData: viewModel.pendingImageData,
                onSend: {
                    if let replying = replyingTo {
                        viewModel.sendMessage(replyingTo: replying)
                        replyingTo = nil
                    } else {
                        viewModel.sendMessage()
                    }
                },
                onStartRecording: {
                    viewModel.startRecording()
                },
                onStopRecording: {
                    viewModel.stopRecording()
                },
                onCancelRecording: {
                    viewModel.cancelRecording()
                },
                onPhotoSelected: { item in
                    viewModel.handlePhotoSelection(item)
                },
                onCameraTapped: {
                    showCamera = true
                },
                onClearPendingImage: {
                    viewModel.clearPendingImage()
                }
            )
            .padding(.bottom, keyboardHeight)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    // Subtract tab bar height (50) since the root view ignores keyboard
                    // and the keyboard frame includes the area behind the tab bar
                    keyboardHeight = frame.height - 50
                }
                // Scroll to bottom after keyboard layout settles
                if let proxy = scrollProxy {
                    scrollToBottom(proxy: proxy, delay: 0.3)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
            // Scroll to bottom after keyboard dismissal settles
            if let proxy = scrollProxy {
                scrollToBottom(proxy: proxy, delay: 0.3)
            }
        }
        .task {
            if !viewModel.isConnected {
                viewModel.connect(to: appState.serverURL, appState: appState)
            }
        }
        .onChange(of: appState.serverURL) { _, newURL in
            viewModel.disconnect()
            viewModel.connect(to: newURL, appState: appState)
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { imageData in
                viewModel.pendingImageData = imageData
            }
        }
    }

    // MARK: - Connection Status Bar

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected: return Color.hubAccentGreen
        case .connecting, .reconnecting: return Color.hubAccentYellow
        case .disconnected, .failed: return Color.hubAccentRed
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .connected: return L10n.chatConnected
        case .connecting: return "Connecting..."
        case .reconnecting(let attempt): return "Reconnecting (\(attempt)/5)..."
        case .disconnected: return L10n.chatDisconnected
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    @ViewBuilder
    private var connectionStatusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            if case .failed = viewModel.connectionState {
                Button("Retry") {
                    viewModel.retry()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.hubPrimary)
                .accessibilityIdentifier(AccessibilityID.chatRetryButton)
            }
        }
        .padding(.horizontal, HubLayout.standardPadding)
        .padding(.vertical, 4)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.8))
    }

    // MARK: - Messages Area

    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                messageStatus: viewModel.messageStatuses[message.id],
                                onReply: { msg in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        replyingTo = msg
                                    }
                                },
                                onScrollToMessage: { targetId in
                                    withAnimation {
                                        proxy.scrollTo(targetId, anchor: .center)
                                    }
                                },
                                onRetry: { msg in
                                    viewModel.retryMessage(msg)
                                },
                                onEdit: { msg, newContent in
                                    viewModel.editMessage(msg, newContent: newContent)
                                },
                                onDelete: { msg in
                                    viewModel.deleteMessage(msg)
                                }
                            )
                            .id(message.id)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }

                    // Show typing indicator when any user message is still
                    // waiting for a response (sending or acknowledged), even if
                    // another message's response is currently streaming.
                    if viewModel.hasMessagesAwaitingResponse {
                        TypingIndicator()
                            .id("typing-indicator")
                    }

                    // Invisible anchor for scrolling.
                    // Also acts as a visibility probe: when it's on screen the user
                    // is at or near the bottom of the chat.
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                        .onAppear {
                            // Bottom anchor became visible — user is at the bottom
                            userScrolledUp = false
                        }
                        .onDisappear {
                            // Bottom anchor scrolled out of view — user scrolled up
                            userScrolledUp = true
                        }
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, 6)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping empty space in the chat area
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
            .accessibilityIdentifier(AccessibilityID.chatMessagesArea)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            // React to ALL message mutations via the trigger counter.
            // This covers: new messages, streaming content updates, and deletions.
            // Only auto-scroll if the user hasn't manually scrolled up.
            .onChange(of: viewModel.messageUpdateTrigger) {
                if !userScrolledUp {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.isTyping) {
                if !userScrolledUp {
                    scrollToBottom(proxy: proxy)
                }
            }
            // When a new user message is sent (message count increases with a user message
            // at the end), always scroll to bottom and reset the flag.
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                if newCount > oldCount,
                   let lastMessage = viewModel.messages.last,
                   lastMessage.role == .user {
                    userScrolledUp = false
                    scrollToBottom(proxy: proxy)
                }
            }
            .onAppear {
                // Store proxy so keyboard handlers can access it.
                scrollProxy = proxy
                // When switching back to the chat tab or chat mode,
                // instant-scroll (no animation) so the user immediately sees latest.
                scrollToBottom(proxy: proxy, animated: false)
                // Follow up with an animated scroll after layout fully settles,
                // in case the first one fired before content was laid out.
                scrollToBottom(proxy: proxy, delay: 0.2)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("\u{1F431}")
                .font(.system(size: 64))

            Text(L10n.chatWelcomeTitle)
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text(L10n.chatWelcomeMessage)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(AccessibilityID.chatEmptyState)
    }

    // MARK: - Question Card

    @ViewBuilder
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.hubAccentYellow)

                Text("Agent Question")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        viewModel.dismissQuestion()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                }
                .accessibilityIdentifier(AccessibilityID.chatQuestionDismiss)
            }

            // Question text
            if let question = viewModel.pendingQuestion {
                Text(question)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            // Option buttons
            if !viewModel.pendingQuestionOptions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.pendingQuestionOptions, id: \.self) { option in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                viewModel.answerQuestion(option)
                                questionFreeTextInput = ""
                            }
                        } label: {
                            Text(option)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                        .stroke(Color.hubPrimary.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // Free text input
            if viewModel.pendingQuestionAllowFreeText {
                HStack(spacing: 8) {
                    TextField("Type a custom answer...", text: $questionFreeTextInput)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                        )
                        .accessibilityIdentifier(AccessibilityID.chatQuestionFreeInput)

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.answerQuestion(questionFreeTextInput)
                            questionFreeTextInput = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                questionFreeTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
                                    : Color.hubPrimary
                            )
                    }
                    .disabled(questionFreeTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(AccessibilityID.chatQuestionFreeSubmit)
                }
            }
        }
        .padding(14)
        .background(AdaptiveColors.surface(for: colorScheme))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier(AccessibilityID.chatQuestionCard)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func replyBar(for message: ChatMessage) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.hubPrimary)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.hubPrimary)

                Text(ChatViewModel.buildReplyPreview(for: message))
                    .font(.system(size: 12))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    replyingTo = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
            }
            .accessibilityIdentifier(AccessibilityID.chatReplyDismiss)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier(AccessibilityID.chatReplyBar)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true, delay: TimeInterval = 0.05) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if animated {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }
}

// MARK: - Camera Image Picker (UIKit wrapper)

/// UIImagePickerController wrapper for camera capture.
struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.7) {
                parent.onImageCaptured(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
        .environment(AppState())
}
