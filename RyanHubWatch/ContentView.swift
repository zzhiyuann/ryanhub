import SwiftUI

// MARK: - Watch Content View

/// Passive display-only view for Watch mic streaming.
/// Start/stop is controlled from the iPhone — this view only shows status.
struct ContentView: View {
    @Environment(WatchAudioStreamer.self) private var streamer

    var body: some View {
        VStack(spacing: 12) {
            // Mic icon — pulsing when streaming, static when idle
            Image(systemName: streamer.isStreaming ? "mic.circle.fill" : "mic.circle")
                .font(.system(size: 44))
                .foregroundStyle(streamer.isStreaming ? .green : .gray)
                .symbolEffect(.pulse, isActive: streamer.isStreaming)

            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundStyle(streamer.isStreaming ? .green : .secondary)
                .multilineTextAlignment(.center)

            // Duration timer when streaming
            if streamer.isStreaming {
                Text(formatDuration(streamer.streamDuration))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var statusText: String {
        if streamer.isStreaming {
            return "Listening..."
        }
        if !streamer.isPhoneConnected {
            return "Connecting..."
        }
        return "Ready"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
        .environment(WatchAudioStreamer())
}
