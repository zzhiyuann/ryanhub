import SwiftUI

// MARK: - Narration Record Button

/// A self-contained recording button component for voice diary entries.
/// Displays different states: idle (mic icon), recording (pulsing + waveform),
/// uploading (progress), and done (checkmark).
///
/// Usage: Embed in BoboView and bind to BoboViewModel.
struct NarrationRecordButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: BoboViewModel

    var body: some View {
        HubCard {
            VStack(spacing: 12) {
                // State-dependent content
                switch viewModel.narrationState {
                case .idle:
                    idleContent
                case .recording:
                    recordingContent
                case .uploading:
                    uploadingContent
                case .done:
                    doneContent
                case .error(let message):
                    errorContent(message)
                }
            }
        }
    }

    // MARK: - Idle State

    private var idleContent: some View {
        Button {
            viewModel.startNarration()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Record Diary")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("Tap to start a voice narration")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recording State

    private var recordingContent: some View {
        VStack(spacing: 12) {
            // Waveform visualization
            waveformView

            // Duration + controls
            HStack {
                // Pulsing red dot + duration
                HStack(spacing: 8) {
                    PulsingDot()

                    Text(formatDuration(viewModel.narrationDuration))
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }

                Spacer()

                // Cancel button
                Button {
                    viewModel.cancelNarration()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)

                // Stop button
                Button {
                    viewModel.stopNarration()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.hubAccentRed)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        GeometryReader { geometry in
            let levels = viewModel.narrationAudioLevels
            let barWidth: CGFloat = 3
            let barSpacing: CGFloat = 2
            let totalBarWidth = barWidth + barSpacing
            let maxBars = Int(geometry.size.width / totalBarWidth)
            let displayLevels = Array(levels.suffix(maxBars))

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.hubPrimary.opacity(0.7))
                        .frame(width: barWidth, height: max(2, level * geometry.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .frame(height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Uploading State

    private var uploadingContent: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.hubPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Uploading & Analyzing...")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(formatDuration(viewModel.narrationDuration) + " recorded")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()
        }
    }

    // MARK: - Done State

    private var doneContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.hubAccentGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("Narration Saved")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(formatDuration(viewModel.narrationDuration) + " — transcribing in background")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()
        }
    }

    // MARK: - Error State

    private func errorContent(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.hubAccentYellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recording Error")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(message)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                viewModel.cancelNarration()
            } label: {
                Text("Dismiss")
                    .font(.hubCaption)
                    .foregroundStyle(Color.hubPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Pulsing Dot

/// A small red circle that pulses to indicate active recording.
private struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.hubAccentRed)
            .frame(width: 10, height: 10)
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Preview

#Preview {
    NarrationRecordButton(viewModel: BoboViewModel())
        .padding()
}
