import SwiftUI
import PhotosUI

/// Main chat screen — the primary interaction surface for Ryan Hub.
/// Telegram-like chat with real-time WebSocket messaging, image, and voice input.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ChatViewModel()
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status bar
                connectionStatusBar

                // Messages area
                messagesArea

                // Input bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    isConnected: viewModel.isConnected,
                    isRecording: viewModel.isRecording,
                    recordingDuration: viewModel.recordingDuration,
                    onSend: {
                        viewModel.sendMessage()
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
                    }
                )
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle(L10n.tabChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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
                    viewModel.connect(to: appState.serverURL)
                }
            }
            .onChange(of: appState.serverURL) { _, newURL in
                viewModel.disconnect()
                viewModel.connect(to: newURL)
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { imageData in
                    viewModel.sendImageMessage(data: imageData)
                }
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
            if reason.contains("Max reconnect") {
                return "Cannot reach Dispatcher"
            }
            return L10n.chatDisconnected
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
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isTyping {
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
    ChatView()
        .environment(AppState())
}
