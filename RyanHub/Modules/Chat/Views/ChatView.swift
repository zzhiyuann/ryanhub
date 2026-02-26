import SwiftUI
import PhotosUI

/// Main chat screen — the primary interaction surface for Ryan Hub.
/// Telegram-like chat with real-time WebSocket messaging, image, and voice input.
/// Supports multi-session chat with a sidebar for session management.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    /// ViewModel is owned by ContentView and passed in, so it survives tab switches.
    @Bindable var viewModel: ChatViewModel
    @State private var showCamera = false
    @State private var showSidebar = false
    @GestureState private var drawerDragOffset: CGFloat = 0
    /// The message the user is replying to (swipe-to-reply).
    @State private var replyingTo: ChatMessage?

    /// Width of the sidebar drawer (80% of screen).
    private var drawerWidth: CGFloat {
        UIScreen.main.bounds.width * 0.8
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // MARK: - Main Chat Content
            NavigationStack {
                VStack(spacing: 0) {
                    // Connection status bar
                    connectionStatusBar

                    // Messages area
                    messagesArea

                    // Reply bar (shown when replying to a message)
                    if let replying = replyingTo {
                        replyBar(for: replying)
                    }

                    // Input bar
                    ChatInputBar(
                        text: $viewModel.inputText,
                        isConnected: viewModel.isConnected,
                        isRecording: viewModel.isRecording,
                        recordingDuration: viewModel.recordingDuration,
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
                }
                .background(AdaptiveColors.background(for: colorScheme))
                .navigationTitle(currentSessionTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSidebar = true
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                viewModel.createNewSession()
                            } label: {
                                Label("New Chat", systemImage: "square.and.pencil")
                            }

                            Button(role: .destructive) {
                                viewModel.clearHistory()
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }
                .task {
                    // Connect once when the view first appears.
                    // Do NOT disconnect on disappear — the connection should persist
                    // across tab switches and navigation.
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

            // MARK: - Scrim Overlay
            if showSidebar {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSidebar = false
                        }
                    }
                    .transition(.opacity)
            }

            // MARK: - Drawer Panel
            ChatSidebarView(
                isPresented: $showSidebar,
                sessions: viewModel.sessions,
                currentSessionId: viewModel.currentSessionId,
                onSelectSession: { id in
                    viewModel.switchSession(id)
                },
                onNewChat: {
                    viewModel.createNewSession()
                },
                onDeleteSession: { id in
                    viewModel.deleteSession(id)
                }
            )
            .frame(width: drawerWidth)
            .offset(x: drawerXOffset)
            .gesture(drawerDragGesture)
        }
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
    }

    // MARK: - Drawer Offset

    /// Computes the x-offset for the drawer panel, combining open/close state with drag gesture.
    private var drawerXOffset: CGFloat {
        let baseOffset = showSidebar ? 0 : -drawerWidth
        // Only apply drag offset when the drawer is open (dragging to close)
        let clampedDrag = min(0, drawerDragOffset)
        return baseOffset + clampedDrag
    }

    /// Drag gesture that allows swiping the drawer closed (drag left).
    private var drawerDragGesture: some Gesture {
        DragGesture()
            .updating($drawerDragOffset) { value, state, _ in
                // Only allow dragging to the left (negative translation)
                if value.translation.width < 0 {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                // Dismiss if dragged more than 30% of drawer width to the left
                if value.translation.width < -(drawerWidth * 0.3) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSidebar = false
                    }
                }
            }
    }

    // MARK: - Session Title

    private var currentSessionTitle: String {
        if let sessionId = viewModel.currentSessionId,
           let session = viewModel.sessions.first(where: { $0.id == sessionId }),
           session.title != "New Chat" {
            return session.title
        }
        return L10n.tabChat
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
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            if case .failed = viewModel.connectionState {
                Button("Retry") {
                    viewModel.retry()
                }
                .font(.hubCaption)
                .foregroundStyle(Color.hubPrimary)
            }
        }
        .padding(.horizontal, HubLayout.standardPadding)
        .padding(.vertical, 6)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.8))
    }

    // MARK: - Messages Area

    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: HubLayout.itemSpacing) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                allMessages: viewModel.messages,
                                onReply: { msg in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        replyingTo = msg
                                    }
                                },
                                onScrollToMessage: { targetId in
                                    withAnimation {
                                        proxy.scrollTo(targetId, anchor: .center)
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }

                    // Show standalone typing indicator ONLY when waiting
                    // for the first response chunk (no streaming message yet).
                    if viewModel.isTyping && viewModel.currentStreamingMessageId == nil {
                        TypingIndicator()
                            .id("typing-indicator")
                    }

                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, HubLayout.itemSpacing)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            // React to ALL message mutations via the trigger counter.
            // This covers: new messages, streaming content updates, and deletions.
            .onChange(of: viewModel.messageUpdateTrigger) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isTyping) {
                scrollToBottom(proxy: proxy)
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

                Text(message.content.isEmpty ? "[Media]" : String(message.content.prefix(80)))
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Small delay to allow the layout to update before scrolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
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
