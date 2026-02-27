import SwiftUI
import PhotosUI

/// Chat input bar with text field, attachment button, voice record, and send button.
/// Fixed at the bottom of the chat, similar to Telegram.
/// Supports attaching a photo and typing a caption before sending.
struct ChatInputBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let isConnected: Bool
    let isRecording: Bool
    let recordingDuration: TimeInterval
    /// Real-time audio level samples (0.0 – 1.0) for waveform visualization.
    let audioLevels: [CGFloat]
    /// Pending image data for preview. Non-nil when a photo is attached but not yet sent.
    let pendingImageData: Data?
    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onCancelRecording: () -> Void
    let onPhotoSelected: (PhotosPickerItem?) -> Void
    let onCameraTapped: () -> Void
    /// Called when the user taps the X on the pending image preview.
    let onClearPendingImage: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = pendingImageData != nil
        return (hasText || hasImage) && isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AdaptiveColors.border(for: colorScheme))

            if isRecording {
                recordingBar
            } else {
                VStack(spacing: 0) {
                    // Pending image preview strip
                    if pendingImageData != nil {
                        pendingImagePreview
                    }

                    standardBar
                }
            }
        }
    }

    // MARK: - Pending Image Preview

    private var pendingImagePreview: some View {
        HStack(spacing: 10) {
            // Thumbnail
            if let data = pendingImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 1)
                    )
            }

            Text("Photo attached")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            // Dismiss button
            Button(action: onClearPendingImage) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
            }
            .accessibilityIdentifier(AccessibilityID.chatClearImageButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier(AccessibilityID.chatPendingImagePreview)
    }

    // MARK: - Standard Input Bar

    private var standardBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attachment button
            attachmentButton

            // Text input
            TextField(
                pendingImageData != nil ? "Add a caption..." : L10n.chatPlaceholder,
                text: $text,
                axis: .vertical
            )
                .font(.hubBody)
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
                            isFocused ? Color.hubPrimary.opacity(0.5) : AdaptiveColors.border(for: colorScheme),
                            lineWidth: 1
                        )
                )
                .accessibilityIdentifier(AccessibilityID.chatInputField)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }

            // Send or microphone button
            if canSend {
                sendButton
            } else {
                microphoneButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
    }

    // MARK: - Recording Bar

    /// Number of waveform bars visible in the recording UI.
    private let waveformBarCount = 30

    private var recordingBar: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: onCancelRecording) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.hubAccentRed)
            }
            .accessibilityIdentifier(AccessibilityID.chatRecordingCancelButton)

            // Recording indicator: red dot + duration
            Circle()
                .fill(Color.hubAccentRed)
                .frame(width: 10, height: 10)

            Text(formatDuration(recordingDuration))
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .fixedSize()

            // Real-time waveform — fills remaining space, centered
            HStack(spacing: 2) {
                ForEach(0..<waveformBarCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.hubAccentRed.opacity(0.7))
                        .frame(width: 3, height: waveformBarHeight(for: index))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)

            // Stop and send button
            Button(action: onStopRecording) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hubPrimary)
            }
            .accessibilityIdentifier(AccessibilityID.chatRecordingStopButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
    }

    // MARK: - Buttons

    private var attachmentButton: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                onCameraTapped()
            } label: {
                Label("Camera", systemImage: "camera")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    isConnected
                        ? Color.hubPrimary
                        : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5)
                )
        }
        .disabled(!isConnected)
        .accessibilityIdentifier(AccessibilityID.chatAttachButton)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newValue in
            if newValue != nil {
                onPhotoSelected(newValue)
                selectedPhotoItem = nil
            }
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.hubPrimary)
        }
        .accessibilityIdentifier(AccessibilityID.chatSendButton)
        .transition(.scale.combined(with: .opacity))
    }

    private var microphoneButton: some View {
        Button(action: onStartRecording) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(
                    isConnected
                        ? AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6)
                        : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3)
                )
        }
        .disabled(!isConnected)
        .accessibilityIdentifier(AccessibilityID.chatMicButton)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helpers

    /// Returns the height for a waveform bar at the given index using real audio levels.
    /// Shows the most recent `waveformBarCount` samples, so the waveform scrolls
    /// from right to left as new audio data arrives.
    private func waveformBarHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 26
        let count = audioLevels.count
        // Map bar index to the tail of the audioLevels array
        let sampleIndex = count - waveformBarCount + index
        guard sampleIndex >= 0, sampleIndex < count else {
            return minHeight
        }
        let level = audioLevels[sampleIndex]
        return minHeight + level * (maxHeight - minHeight)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputBar(
            text: .constant("Hello"),
            isConnected: true,
            isRecording: false,
            recordingDuration: 0,
            audioLevels: [],
            pendingImageData: nil,
            onSend: { print("Send") },
            onStartRecording: { print("Record") },
            onStopRecording: { print("Stop") },
            onCancelRecording: { print("Cancel") },
            onPhotoSelected: { _ in },
            onCameraTapped: { print("Camera") },
            onClearPendingImage: { print("Clear image") }
        )
    }
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
