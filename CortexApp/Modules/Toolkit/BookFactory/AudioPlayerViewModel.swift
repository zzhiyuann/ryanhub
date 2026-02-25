import Foundation
import AVFoundation
import MediaPlayer

/// Manages audio playback for Book Factory — chunk-based streaming with chapter navigation,
/// speed control, and Now Playing integration.
@MainActor @Observable
final class AudioPlayerViewModel: NSObject {
    var currentBook: (id: String, title: String)?
    var manifest: AudioManifest?
    var isPlaying = false
    var isBuffering = false
    var currentTime: Double = 0
    var currentChunkIndex = 0
    var playbackSpeed: Float = 1.0
    var showFullPlayer = false

    var totalDuration: Double {
        guard let m = manifest else { return 0 }
        if m.isComplete {
            return m.totalDuration
        }
        return m.estimatedTotalDuration ?? m.totalDuration
    }

    var currentChapter: ChapterMarker? {
        manifest?.chapters.last(where: { $0.startTime <= currentTime })
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var chunkBaseTimes: [Double] = []
    private let api: BookFactoryAPI
    private var manifestPollTask: Task<Void, Never>?
    private var endObserver: NSObjectProtocol?

    init(api: BookFactoryAPI) {
        self.api = api
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }

    // MARK: - Audio Session

    private nonisolated func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Remote Commands (Lock Screen / Control Center)

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: 15) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: -15) }
            return .success
        }
    }

    // MARK: - Playback Control

    func startPlaying(bookId: String, title: String) async {
        stop()
        currentBook = (id: bookId, title: title)
        isBuffering = true

        do {
            let m: AudioManifest = try await api.get("/api/audiobook/\(bookId)/manifest")
            manifest = m
            buildChunkBaseTimes()

            if m.readyChunks > 0 {
                playChunk(index: 0)
            }

            if !m.isComplete {
                startManifestPolling(bookId: bookId)
            }
        } catch {
            print("Failed to load manifest: \(error)")
            isBuffering = false
        }
    }

    func play() {
        player?.play()
        player?.rate = playbackSpeed
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func stop() {
        manifestPollTask?.cancel()
        manifestPollTask = nil
        removeTimeObserver()
        removeEndObserver()
        player?.pause()
        player = nil
        isPlaying = false
        isBuffering = false
        currentBook = nil
        manifest = nil
        currentTime = 0
        currentChunkIndex = 0
        chunkBaseTimes = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: Double) {
        guard let manifest else { return }
        var targetChunk = 0
        var accumulated: Double = 0
        for (i, chunk) in manifest.chunks.enumerated() {
            if accumulated + chunk.duration > time {
                targetChunk = i
                break
            }
            accumulated += chunk.duration
            if i == manifest.chunks.count - 1 { targetChunk = i }
        }

        let offsetInChunk = time - accumulated
        if targetChunk == currentChunkIndex {
            let cmTime = CMTime(seconds: max(0, offsetInChunk), preferredTimescale: 600)
            player?.seek(to: cmTime)
            currentTime = time
        } else if targetChunk < manifest.readyChunks {
            playChunk(index: targetChunk, seekTo: max(0, offsetInChunk))
        }
        updateNowPlaying()
    }

    func skip(seconds: Double) {
        seek(to: max(0, min(currentTime + seconds, totalDuration)))
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying { player?.rate = speed }
        updateNowPlaying()
    }

    func seekToChapter(_ chapter: ChapterMarker) {
        seek(to: chapter.startTime)
    }

    // MARK: - Private: Chunk Playback

    private func buildChunkBaseTimes() {
        guard let manifest else { return }
        chunkBaseTimes = []
        var acc: Double = 0
        for chunk in manifest.chunks {
            chunkBaseTimes.append(acc)
            acc += chunk.duration
        }
    }

    private func playChunk(index: Int, seekTo offset: Double? = nil) {
        guard let bookId = currentBook?.id,
              let url = api.chunkURL(bookId: bookId, index: index) else { return }

        removeTimeObserver()
        removeEndObserver()

        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        currentChunkIndex = index

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleChunkEnd()
            }
        }

        if let offset {
            let cmTime = CMTime(seconds: offset, preferredTimescale: 600)
            player?.seek(to: cmTime) { [weak self] _ in
                Task { @MainActor in self?.play() }
            }
        } else {
            play()
        }
        isBuffering = false
        addTimeObserver()
    }

    private func handleChunkEnd() {
        let nextIndex = currentChunkIndex + 1
        guard let manifest else { return }

        if nextIndex < manifest.readyChunks {
            playChunk(index: nextIndex)
        } else if !manifest.isComplete && nextIndex < manifest.totalChunks {
            // Waiting for more chunks to be generated
            isBuffering = true
            isPlaying = false
        } else {
            // Finished all chunks
            isPlaying = false
            currentTime = totalDuration
            updateNowPlaying()
        }
    }

    // MARK: - Private: Time Observation

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] cmTime in
            Task { @MainActor [weak self] in
                guard let self, self.currentChunkIndex < self.chunkBaseTimes.count else { return }
                let base = self.chunkBaseTimes[self.currentChunkIndex]
                self.currentTime = base + cmTime.seconds
                self.updateNowPlaying()
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func removeEndObserver() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
    }

    // MARK: - Private: Now Playing

    private func updateNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentBook?.title ?? "Book Factory"
        info[MPMediaItemPropertyPlaybackDuration] = totalDuration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Private: Manifest Polling (for in-progress audio generation)

    private func startManifestPolling(bookId: String) {
        manifestPollTask?.cancel()
        manifestPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                do {
                    let m: AudioManifest = try await self.api.get("/api/audiobook/\(bookId)/manifest")
                    let wasBuffering = self.isBuffering
                    self.manifest = m
                    self.buildChunkBaseTimes()

                    // If we were waiting for the next chunk, resume playback
                    if wasBuffering {
                        let nextIndex = self.currentChunkIndex + 1
                        if nextIndex < m.readyChunks {
                            self.playChunk(index: nextIndex)
                        }
                    }

                    if m.isComplete {
                        self.manifestPollTask?.cancel()
                    }
                } catch {
                    // retry on next cycle
                }
            }
        }
    }
}
