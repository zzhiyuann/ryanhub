import AVFoundation
import HealthKit
import WatchConnectivity

// MARK: - Watch Audio Streamer

/// Captures microphone audio on Apple Watch and streams PCM data to the paired iPhone.
///
/// - Receives start/stop commands from iPhone via WCSession messages.
/// - Uses HKWorkoutSession (mindfulness) to keep the app alive in the background.
/// - Captures 16kHz mono Int16 PCM via AVAudioEngine.
/// - Sends PCM batches every 0.5s via `WCSession.sendMessageData()`.
@Observable
final class WatchAudioStreamer: NSObject {
    // MARK: - Observable State

    /// Whether audio is currently being captured and streamed.
    private(set) var isStreaming = false

    /// Whether the WCSession is activated and paired with the iPhone.
    /// This is stable (unlike isReachable which flickers constantly).
    private(set) var isPhoneConnected = false

    /// Duration of the current streaming session.
    private(set) var streamDuration: TimeInterval = 0

    // MARK: - Configuration

    private let sampleRate: Double = 16000
    private let channelCount: AVAudioChannelCount = 1
    private let sendInterval: TimeInterval = 0.5

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var pcmBuffer: [Int16] = []
    private let bufferLock = NSLock()
    private var sendTimer: Timer?

    // MARK: - HealthKit Workout Session

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?

    // MARK: - WCSession

    private var wcSession: WCSession?

    // MARK: - Timing

    private var streamStartTime: Date?
    private var durationTimer: Timer?

    /// Debounce timer — only used to delay stopping capture on unreachable.
    private var unreachableDebounceTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        setupWCSession()
    }

    // MARK: - WCSession Setup

    private func setupWCSession() {
        guard WCSession.isSupported() else {
            print("[WatchAudioStreamer] WCSession not supported")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    // MARK: - Capture Lifecycle

    /// Start audio capture: workout session + audio engine + send timer.
    func startCapture() {
        guard !isStreaming else { return }
        print("[WatchAudioStreamer] Starting capture")

        // 1. Start HKWorkoutSession for background keepalive
        startWorkoutSession()

        // 2. Configure AVAudioSession
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("[WatchAudioStreamer] AVAudioSession setup failed: \(error.localizedDescription)")
            return
        }

        // 3. Start AVAudioEngine
        do {
            try setupAudioEngine()
        } catch {
            print("[WatchAudioStreamer] Audio engine setup failed: \(error.localizedDescription)")
            return
        }

        // 4. Start send timer
        isStreaming = true
        streamStartTime = Date()
        startSendTimer()
        startDurationTimer()

        print("[WatchAudioStreamer] Capture started")
    }

    /// Stop audio capture and clean up.
    func stopCapture() {
        guard isStreaming else { return }
        print("[WatchAudioStreamer] Stopping capture")

        isStreaming = false

        // Stop timers
        sendTimer?.invalidate()
        sendTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        streamDuration = 0
        streamStartTime = nil

        // Stop audio engine
        if let engine = audioEngine, engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        // End workout session
        stopWorkoutSession()

        print("[WatchAudioStreamer] Capture stopped")
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: true
        ) else {
            throw WatchAudioError.formatCreationFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw WatchAudioError.converterCreationFailed
        }

        bufferLock.lock()
        pcmBuffer.removeAll()
        bufferLock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
        self.audioEngine = engine
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else { return }

        if let int16Data = outputBuffer.int16ChannelData {
            let frameCount = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameCount))
            bufferLock.lock()
            pcmBuffer.append(contentsOf: samples)
            bufferLock.unlock()
        }
    }

    // MARK: - Periodic Send

    private func startSendTimer() {
        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(withTimeInterval: sendInterval, repeats: true) { [weak self] _ in
            self?.drainAndSendBuffer()
        }
    }

    private func drainAndSendBuffer() {
        guard isStreaming, let session = wcSession, session.isReachable else { return }

        bufferLock.lock()
        let samples = pcmBuffer
        pcmBuffer.removeAll()
        bufferLock.unlock()

        guard !samples.isEmpty else { return }

        let data = samples.withUnsafeBytes { Data($0) }
        session.sendMessageData(data, replyHandler: nil) { error in
            print("[WatchAudioStreamer] Failed to send audio data: \(error.localizedDescription)")
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.streamStartTime else { return }
            self.streamDuration = Date().timeIntervalSince(start)
        }
    }

    // MARK: - HKWorkoutSession (Background Keepalive)

    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[WatchAudioStreamer] HealthKit not available")
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.startActivity(with: Date())
            workoutSession = session
            print("[WatchAudioStreamer] Workout session started (mindfulness keepalive)")
        } catch {
            print("[WatchAudioStreamer] Failed to start workout session: \(error.localizedDescription)")
        }
    }

    private func stopWorkoutSession() {
        workoutSession?.end()
        workoutSession = nil
        print("[WatchAudioStreamer] Workout session ended")
    }
}

// MARK: - WCSessionDelegate

extension WatchAudioStreamer: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("[WatchAudioStreamer] WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("[WatchAudioStreamer] WCSession activated: \(activationState.rawValue), companionInstalled: \(session.isCompanionAppInstalled)")
            DispatchQueue.main.async { [weak self] in
                self?.isPhoneConnected = (activationState == .activated)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        print("[WatchAudioStreamer] Phone reachability changed: \(reachable)")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Cancel any pending debounce
            self.unreachableDebounceTimer?.invalidate()
            self.unreachableDebounceTimer = nil

            if !reachable && self.isStreaming {
                // Debounce: only stop capture if unreachable persists for 5 seconds
                self.unreachableDebounceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    let stillUnreachable = !(self.wcSession?.isReachable ?? false)
                    if stillUnreachable && self.isStreaming {
                        print("[WatchAudioStreamer] Phone unreachable (confirmed after 5s) — stopping capture")
                        self.stopCapture()
                    }
                }
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            switch message["command"] as? String {
            case "start_audio":
                self?.startCapture()
            case "stop_audio":
                self?.stopCapture()
            default:
                break
            }
        }
    }
}

// MARK: - Errors

private enum WatchAudioError: LocalizedError {
    case formatCreationFailed
    case converterCreationFailed

    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create target audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        }
    }
}
