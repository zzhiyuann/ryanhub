import SwiftUI

/// Full-screen audio player with scrubber, chapter list, and speed controls.
/// Presented as a sheet from the mini player.
struct AudioPlayerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AudioPlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Book cover placeholder
                bookCover

                // Title + Chapter
                VStack(spacing: 6) {
                    Text(player.currentBook?.title ?? "")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let chapter = player.currentChapter {
                        Text(chapter.title)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)

                // Scrubber
                scrubber

                // Main controls
                playbackControls

                // Speed control
                speedSelector

                // Chapters
                if let chapters = player.manifest?.chapters, !chapters.isEmpty {
                    chapterList(chapters)
                }

                Spacer()
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Book Cover

    private var bookCover: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        Color.hubPrimary.opacity(0.3),
                        Color.hubPrimaryLight.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 200, height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.hubPrimary)
                    Text(player.currentBook?.title ?? "")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 16)
                }
            }
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.totalDuration, 1)
            )
            .tint(.hubPrimary)

            HStack {
                Text(BookFormatting.duration(player.currentTime))
                Spacer()
                Text("-\(BookFormatting.duration(max(0, player.totalDuration - player.currentTime)))")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 40) {
            AudioSkipButton(systemName: "gobackward.15") {
                player.skip(seconds: -15)
            }
            .font(.title)

            Button { player.togglePlayPause() } label: {
                ZStack {
                    if player.isBuffering {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.hubPrimary)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.hubPrimary)
                    }
                }
                .frame(width: 64, height: 64)
            }

            AudioSkipButton(systemName: "goforward.15") {
                player.skip(seconds: 15)
            }
            .font(.title)
        }
    }

    // MARK: - Speed Selector

    private var speedSelector: some View {
        HStack(spacing: 12) {
            ForEach(speeds, id: \.self) { speed in
                Button {
                    player.setSpeed(speed)
                } label: {
                    Text(speed == 1.0 ? "1x" : String(format: "%.2gx", speed))
                        .font(.system(
                            size: 13,
                            weight: player.playbackSpeed == speed ? .bold : .regular
                        ))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            player.playbackSpeed == speed
                                ? Color.hubPrimary.opacity(0.2)
                                : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            player.playbackSpeed == speed
                                ? Color.hubPrimary
                                : AdaptiveColors.textSecondary(for: colorScheme)
                        )
                }
            }
        }
    }

    // MARK: - Chapter List

    private func chapterList(_ chapters: [ChapterMarker]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Chapters")
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(chapters) { chapter in
                        Button {
                            player.seekToChapter(chapter)
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.hubCaption)
                                    .lineLimit(1)
                                    .foregroundStyle(
                                        player.currentChapter?.title == chapter.title
                                            ? Color.hubPrimary
                                            : AdaptiveColors.textPrimary(for: colorScheme)
                                    )
                                Spacer()
                                Text(BookFormatting.duration(chapter.startTime))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .frame(maxHeight: 160)
        }
    }
}

// MARK: - Skip Button with Haptic Feedback

struct AudioSkipButton: View {
    let systemName: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title3)
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
