import SwiftUI
import PhotosUI

/// Chat input bar with text field, attachment button, voice record, and send button.
/// Fixed at the bottom of the chat, similar to Telegram.
struct ChatInputBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let isConnected: Bool
    let isRecording: Bool
    let recordingDuration: TimeInterval
    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onCancelRecording: () -> Void
    let onPhotoSelected: (PhotosPickerItem?) -> Void
    let onCameraTapped: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AdaptiveColors.border(for: colorScheme))

            if isRecording {
                recordingBar
            } else {
                standardBar
            }
        }
    }

    // MARK: - Standard Input Bar

    private var standardBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attachment button
            attachmentButton

            // Text input
            TextField(L10n.chatPlaceholder, text: $text, axis: .vertical)
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

    private var recordingBar: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: onCancelRecording) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.hubAccentRed)
            }

            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.hubAccentRed)
                    .frame(width: 10, height: 10)

                Text(formatDuration(recordingDuration))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                // Waveform animation
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.hubAccentRed.opacity(0.6))
                            .frame(width: 3, height: recordingBarHeight(for: index))
                    }
                }
                .frame(height: 24)
            }

            Spacer()

            // Stop and send button
            Button(action: onStopRecording) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hubPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.95))
    }

    // MARK: - Buttons

    private var attachmentButton: some View {
        Menu {
            PhotosPicker(
                selection: Binding(
                    get: { selectedPhotoItem },
                    set: { newValue in
                        selectedPhotoItem = newValue
                        onPhotoSelected(newValue)
                    }
                ),
                matching: .images
            ) {
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
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.hubPrimary)
        }
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
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helpers

    private func recordingBarHeight(for index: Int) -> CGFloat {
        let time = recordingDuration
        let phase = sin(time * 4 + Double(index) * 0.5)
        return CGFloat(6 + phase * 9)
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
            onSend: { print("Send") },
            onStartRecording: { print("Record") },
            onStopRecording: { print("Stop") },
            onCancelRecording: { print("Cancel") },
            onPhotoSelected: { _ in },
            onCameraTapped: { print("Camera") }
        )
    }
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
