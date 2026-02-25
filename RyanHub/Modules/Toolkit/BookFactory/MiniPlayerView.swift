import SwiftUI

/// Compact audio player overlay shown at the bottom of the Book Factory view.
/// Displays current track info, playback progress, and basic controls.
/// Taps open the full AudioPlayerView as a sheet.
struct MiniPlayerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AudioPlayerViewModel.self) private var player

    var body: some View {
        if player.currentBook != nil {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AdaptiveColors.border(for: colorScheme))
                        Rectangle()
                            .fill(Color.hubPrimary)
                            .frame(width: geo.size.width * progressFraction)
                    }
                }
                .frame(height: 3)

                HStack(spacing: 12) {
                    // Book title and time
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentBook?.title ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(BookFormatting.duration(player.currentTime))
                            Text("/")
                            Text(BookFormatting.duration(player.totalDuration))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    if player.isBuffering {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.hubPrimary)
                    }

                    // Controls
                    AudioSkipButton(systemName: "gobackward.15") {
                        player.skip(seconds: -15)
                    }
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(Color.hubPrimary)
                    }

                    AudioSkipButton(systemName: "goforward.15") {
                        player.skip(seconds: 15)
                    }
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Button { player.stop() } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, 8)
            }
            .background(AdaptiveColors.surface(for: colorScheme))
            .onTapGesture {
                player.showFullPlayer = true
            }
            .sheet(isPresented: Bindable(player).showFullPlayer) {
                AudioPlayerView(player: player)
            }
        }
    }

    private var progressFraction: CGFloat {
        guard player.totalDuration > 0 else { return 0 }
        return CGFloat(player.currentTime / player.totalDuration)
    }
}
