import Foundation
import AVFoundation

// MARK: - Audio Stream Sensor

/// Always-on microphone sensor that streams audio to a diarization server via WebSocket.
///
/// Uses Silero VAD on the server side to detect speech segments, runs Whisper for
/// fast transcription, then async diarization for speaker labels. Results arrive
/// as separate messages: "transcript" first (~2-3s), then "speaker" enrichment (~5-10s).
///
/// Protocol:
/// - Client sends `{"type": "start"}` to begin a streaming session.
/// - Client sends raw 16kHz mono 16-bit PCM binary frames every ~0.5s.
/// - Client sends `{"type": "stop"}` to end the session.
/// - Server replies with transcript, speaker, vad, status, and error JSON messages.
final class AudioStreamSensor {
    private var isRunning = false

    /// Tracks whether the WebSocket connection is alive.
    /// Set to false when the receive loop encounters an error or cancellation.
    private var isWebSocketConnected = false

    /// Tracks whether the audio engine needs a restart (e.g. after an interruption).
    private var needsAudioRestart = false

    /// Whether audio is coming from a local mic or an external source (e.g. Watch).
    enum AudioSource { case local, watch }
    private(set) var currentSource: AudioSource = .local

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Configuration

    /// Audio format: 16kHz mono 16-bit PCM (required by diarization server).
    private let sampleRate: Double = 16000
    private let channelCount: AVAudioChannelCount = 1

    /// Interval at which buffered PCM data is sent via WebSocket (~0.5s).
    private let sendInterval: TimeInterval = 0.5

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()

    /// Buffer that accumulates raw PCM samples between send intervals.
    private var pcmBuffer: [Int16] = []

    /// Lock to protect pcmBuffer access from the audio tap callback.
    private let bufferLock = NSLock()

    /// Timer that periodically drains the PCM buffer and sends it over WebSocket.
    private var sendTimer: Timer?

    // MARK: - WebSocket

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?

    // MARK: - Server URL

    /// WebSocket URL for the streaming diarization server.
    /// Extracts the host from the shared bridge server URL and uses port 18794.
    private static var streamURL: URL? {
        let host = UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            ?? "localhost"
        return URL(string: "ws://\(host):18794/ws/stream")
    }

    // MARK: - Lifecycle

    /// Start the WebSocket connection and audio capture.
    /// Requests microphone permission if not already granted.
    func start() {
        guard !isRunning else { return }

        #if os(iOS)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else {
                print("[AudioStreamSensor] Microphone permission denied")
                return
            }
            DispatchQueue.main.async {
                self?.beginStreaming()
            }
        }
        #else
        print("[AudioStreamSensor] Audio capture is only supported on iOS")
        #endif
    }

    /// Stop audio capture and disconnect the WebSocket.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        isWebSocketConnected = false
        needsAudioRestart = false

        // Remove audio session interruption observer
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)

        // Stop the send timer
        sendTimer?.invalidate()
        sendTimer = nil

        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        // Send stop message and disconnect
        sendStopAndDisconnect()

        print("[AudioStreamSensor] Stopped")
    }

    /// Resume the sensor if it should be running but the WebSocket or AudioEngine has died.
    /// This handles the case where iOS suspends the app in the background, killing the
    /// WebSocket connection and audio engine tap. On foreground return, `isRunning` is
    /// still true but everything is dead — this method performs a clean restart.
    func resumeIfNeeded() {
        guard isRunning else { return }

        let wsAlive = isWebSocketConnected
        let engineAlive = audioEngine.isRunning

        if wsAlive && engineAlive && !needsAudioRestart {
            // Everything is fine, nothing to do
            return
        }

        print("[AudioStreamSensor] Resuming — ws=\(wsAlive), engine=\(engineAlive), needsRestart=\(needsAudioRestart)")

        // Clean restart: stop everything, then start fresh
        stop()
        start()
    }

    // MARK: - Streaming Setup

    /// Connect to the WebSocket, send a start message, and begin audio capture.
    private func beginStreaming() {
        // Connect WebSocket
        guard let url = Self.streamURL else {
            print("[AudioStreamSensor] Invalid stream URL")
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        self.urlSession = session

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        isWebSocketConnected = true

        // Send start message
        let startMessage = "{\"type\": \"start\"}"
        task.send(.string(startMessage)) { [weak self] error in
            if let error {
                print("[AudioStreamSensor] Failed to send start message: \(error.localizedDescription)")
                self?.emitErrorEvent(message: "WebSocket start failed: \(error.localizedDescription)")
                return
            }
            print("[AudioStreamSensor] Sent start message")
        }

        // Start receiving server messages
        startReceiving()

        // Set up audio engine and begin capture
        do {
            try setupAudioEngine()
            isRunning = true
            needsAudioRestart = false

            // Listen for audio session interruptions (e.g. phone call, Siri)
            // so we can mark the sensor as needing a restart on foreground resume.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioInterruption(_:)),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )

            // Emit a "listening" event to indicate streaming is active
            let listeningEvent = SensingEvent(
                modality: .audio,
                payload: ["status": "listening"]
            )
            onEvent?(listeningEvent)

            // Start the periodic send timer
            startSendTimer()

            print("[AudioStreamSensor] Started streaming to \(url.absoluteString)")
        } catch {
            print("[AudioStreamSensor] Failed to start audio engine: \(error.localizedDescription)")
            emitErrorEvent(message: "Audio engine failed: \(error.localizedDescription)")
            disconnectWebSocket()
        }
    }

    /// Configure AVAudioEngine with a tap for 16kHz mono Int16 PCM capture.
    private func setupAudioEngine() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)
        #endif

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create the target format: 16kHz mono 16-bit PCM
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: true
        ) else {
            throw AudioStreamError.formatCreationFailed
        }

        // Create converter from hardware format to target format
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioStreamError.converterCreationFailed
        }

        // Reset buffer
        bufferLock.lock()
        pcmBuffer.removeAll()
        bufferLock.unlock()

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Process incoming audio buffer: convert to 16kHz mono Int16 and append to pcmBuffer.
    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        // Calculate output frame capacity based on sample rate ratio
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

        guard status != .error, error == nil else {
            if let error {
                print("[AudioStreamSensor] Conversion error: \(error.localizedDescription)")
            }
            return
        }

        // Append converted Int16 samples to our buffer
        if let int16Data = outputBuffer.int16ChannelData {
            let frameCount = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameCount))

            bufferLock.lock()
            pcmBuffer.append(contentsOf: samples)
            bufferLock.unlock()
        }
    }

    // MARK: - Periodic Send

    /// Start a timer that drains the PCM buffer and sends data over WebSocket every ~0.5s.
    private func startSendTimer() {
        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(withTimeInterval: sendInterval, repeats: true) { [weak self] _ in
            self?.drainAndSendBuffer()
        }
    }

    /// Drain the PCM buffer and send its contents as a binary WebSocket frame.
    private func drainAndSendBuffer() {
        guard isRunning, let task = webSocketTask else { return }

        bufferLock.lock()
        let samples = pcmBuffer
        pcmBuffer.removeAll()
        bufferLock.unlock()

        guard !samples.isEmpty else { return }

        // Convert Int16 samples to raw bytes (little-endian, native on iOS)
        let data = samples.withUnsafeBytes { Data($0) }

        task.send(.data(data)) { error in
            if let error {
                print("[AudioStreamSensor] Failed to send audio data: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - WebSocket Receiving

    /// Start a loop that receives and processes messages from the server.
    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let task = self.webSocketTask else { break }
                do {
                    let message = try await task.receive()
                    await MainActor.run {
                        self.handleServerMessage(message)
                    }
                } catch {
                    if !Task.isCancelled {
                        print("[AudioStreamSensor] WebSocket receive error: \(error.localizedDescription)")
                    }
                    await MainActor.run {
                        self.isWebSocketConnected = false
                    }
                    break
                }
            }
        }
    }

    /// Parse and handle a message received from the diarization server.
    private func handleServerMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "transcript":
            handleTranscriptMessage(json)
        case "speaker":
            handleSpeakerMessage(json)
        case "vad":
            handleVADMessage(json)
        case "status":
            handleStatusMessage(json)
        case "error":
            handleErrorMessage(json)
        default:
            print("[AudioStreamSensor] Unknown message type: \(type)")
        }
    }

    /// Handle a transcript message: emit a SensingEvent with the transcribed text.
    private func handleTranscriptMessage(_ json: [String: Any]) {
        let text = json["text"] as? String ?? ""
        let segmentId = json["segment_id"] as? String ?? ""
        let start = json["start"] as? Double ?? 0.0
        let end = json["end"] as? Double ?? 0.0
        let isPartial = json["is_partial"] as? Bool ?? false

        // Skip empty or partial transcripts
        guard !text.isEmpty, !isPartial else { return }

        let event = SensingEvent(
            modality: .audio,
            payload: [
                "status": "transcript",
                "text": text,
                "segmentId": segmentId,
                "start": String(format: "%.1f", start),
                "end": String(format: "%.1f", end)
            ]
        )
        onEvent?(event)

        print("[AudioStreamSensor] Transcript [seg=\(segmentId)]: \(text.prefix(60))")
    }

    /// Handle a speaker identification message: emit a speaker_update event.
    private func handleSpeakerMessage(_ json: [String: Any]) {
        let segmentId = json["segment_id"] as? String ?? ""
        let speaker = json["speaker"] as? String ?? "unknown"
        let confidence = json["confidence"] as? Double ?? 0.0

        let event = SensingEvent(
            modality: .audio,
            payload: [
                "status": "speaker_update",
                "segmentId": segmentId,
                "speaker": speaker,
                "confidence": String(format: "%.3f", confidence)
            ]
        )
        onEvent?(event)

        print("[AudioStreamSensor] Speaker [seg=\(segmentId)]: \(speaker) (conf=\(String(format: "%.2f", confidence)))")
    }

    /// Handle a VAD (voice activity detection) event.
    private func handleVADMessage(_ json: [String: Any]) {
        let isSpeech = json["speech"] as? Bool ?? false
        print("[AudioStreamSensor] VAD: speech=\(isSpeech)")
    }

    /// Handle a status message from the server.
    private func handleStatusMessage(_ json: [String: Any]) {
        let statusMessage = json["message"] as? String ?? ""
        let profiles = json["profiles"] as? [String] ?? []
        print("[AudioStreamSensor] Status: \(statusMessage), profiles: \(profiles)")
    }

    /// Handle an error message from the server.
    private func handleErrorMessage(_ json: [String: Any]) {
        let message = json["message"] as? String ?? "Unknown server error"
        print("[AudioStreamSensor] Server error: \(message)")
        emitErrorEvent(message: message)
    }

    // MARK: - Audio Session Interruption

    /// Handle AVAudioSession interruption notifications (e.g. phone call, Siri).
    /// Marks the sensor as needing a restart so `resumeIfNeeded()` can recover it
    /// when the app returns to the foreground.
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[AudioStreamSensor] Audio session interrupted")
            needsAudioRestart = true
        case .ended:
            print("[AudioStreamSensor] Audio session interruption ended — will restart on foreground resume")
            needsAudioRestart = true
        @unknown default:
            break
        }
    }

    // MARK: - WebSocket Disconnect

    /// Send a stop message and close the WebSocket connection.
    private func sendStopAndDisconnect() {
        guard let task = webSocketTask else { return }

        let stopMessage = "{\"type\": \"stop\"}"
        task.send(.string(stopMessage)) { [weak self] _ in
            self?.disconnectWebSocket()
        }
    }

    /// Close the WebSocket connection and clean up.
    private func disconnectWebSocket() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isWebSocketConnected = false
    }

    // MARK: - Event Helpers

    /// Emit an error event via the onEvent callback.
    private func emitErrorEvent(message: String) {
        let event = SensingEvent(
            modality: .audio,
            payload: [
                "status": "error",
                "error": message
            ]
        )
        onEvent?(event)
    }

    // MARK: - External Audio Source (Watch)

    /// Feed raw PCM data from an external source (e.g. Apple Watch mic).
    /// Writes directly to the WebSocket, bypassing the local AVAudioEngine.
    func feedExternalAudio(_ data: Data) {
        guard isRunning, currentSource == .watch, let task = webSocketTask else { return }
        task.send(.data(data)) { error in
            if let error {
                print("[AudioStreamSensor] Failed to send external audio data: \(error.localizedDescription)")
            }
        }
    }

    /// Switch to external audio source: stop the local AVAudioEngine but keep the
    /// WebSocket connection alive to receive data from `feedExternalAudio()`.
    func switchToExternalSource() {
        currentSource = .watch

        // Stop local audio capture (timer + engine) but keep WebSocket open
        sendTimer?.invalidate()
        sendTimer = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        print("[AudioStreamSensor] Switched to external audio source (Watch)")
    }

    /// Switch back to local microphone: restart the AVAudioEngine and send timer.
    func switchToLocalSource() {
        currentSource = .local

        guard isRunning else { return }

        // Restart local audio engine
        do {
            try setupAudioEngine()
            startSendTimer()
            print("[AudioStreamSensor] Switched back to local audio source")
        } catch {
            print("[AudioStreamSensor] Failed to restart local audio: \(error.localizedDescription)")
            emitErrorEvent(message: "Local audio restart failed: \(error.localizedDescription)")
        }
    }

    /// Start streaming in external mode: connect WebSocket and send start message,
    /// but do NOT start the local AVAudioEngine. Audio will come via `feedExternalAudio()`.
    func startExternal() {
        guard !isRunning else { return }
        currentSource = .watch

        #if os(iOS)
        // Connect WebSocket only — no mic permission or audio engine needed
        guard let url = Self.streamURL else {
            print("[AudioStreamSensor] Invalid stream URL")
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        self.urlSession = session

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        isWebSocketConnected = true

        // Send start message
        let startMessage = "{\"type\": \"start\"}"
        task.send(.string(startMessage)) { [weak self] error in
            if let error {
                print("[AudioStreamSensor] Failed to send start message: \(error.localizedDescription)")
                self?.emitErrorEvent(message: "WebSocket start failed: \(error.localizedDescription)")
                return
            }
            print("[AudioStreamSensor] Sent start message (external mode)")
        }

        startReceiving()
        isRunning = true
        needsAudioRestart = false

        let listeningEvent = SensingEvent(
            modality: .audio,
            payload: ["status": "listening", "source": "watch"]
        )
        onEvent?(listeningEvent)

        print("[AudioStreamSensor] Started in external mode (Watch) — WebSocket only")
        #endif
    }
}

// MARK: - Errors

private enum AudioStreamError: LocalizedError {
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
