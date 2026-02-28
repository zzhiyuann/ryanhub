import Foundation
import AVFoundation

// MARK: - Audio Stream Sensor

/// Always-on microphone sensor that streams audio chunks to a diarization server
/// for transcription and speaker identification.
///
/// Records audio in configurable chunks (default 30s) using AVAudioEngine,
/// then POSTs each chunk as a raw WAV file to the diarization server's
/// `/process` endpoint. Results are emitted as SensingEvents with transcription
/// and speaker information.
///
/// This sensor operates independently from the main sensing toggle due to its
/// battery and privacy implications — it requires explicit user opt-in.
final class AudioStreamSensor {
    private var isRunning = false

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Configuration

    /// Duration of each audio chunk in seconds.
    private let chunkDuration: TimeInterval = 30

    /// Audio format: 16kHz mono 16-bit PCM (required by diarization server).
    private let sampleRate: Double = 16000
    private let channelCount: AVAudioChannelCount = 1

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private var chunkTimer: Timer?
    private var currentChunkIndex: Int = 0

    /// Buffer that accumulates raw PCM samples for the current chunk.
    private var pcmBuffer: [Int16] = []

    /// Lock to protect pcmBuffer access from the audio tap callback.
    private let bufferLock = NSLock()

    /// Serial queue for processing completed chunks without blocking recording.
    private let processingQueue = DispatchQueue(
        label: "com.ryanhub.popo.audiostream",
        qos: .utility
    )

    // MARK: - Server URL

    /// Base URL for the diarization server, derived from the shared server URL setting.
    /// Extracts the host from the bridge server URL and uses port 18793.
    private static var diarizationBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18793" }
            ?? "http://localhost:18793"
    }

    // MARK: - Lifecycle

    /// Start recording audio in chunks and streaming to the diarization server.
    /// Requests microphone permission if not already granted.
    func start() {
        guard !isRunning else { return }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else {
                print("[AudioStreamSensor] Microphone permission denied")
                return
            }
            DispatchQueue.main.async {
                self?.beginRecording()
            }
        }
    }

    /// Stop recording and cancel any pending chunk processing.
    func stop() {
        guard isRunning else { return }
        isRunning = false

        chunkTimer?.invalidate()
        chunkTimer = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        // Process any remaining buffered audio
        finalizeCurrentChunk()

        print("[AudioStreamSensor] Stopped")
    }

    // MARK: - Recording

    /// Configure the audio session, install the tap, and start the engine.
    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)

            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Create the target format: 16kHz mono 16-bit PCM
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: channelCount,
                interleaved: true
            ) else {
                print("[AudioStreamSensor] Failed to create target audio format")
                return
            }

            // Install a converter if the hardware format differs from our target
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                print("[AudioStreamSensor] Failed to create audio converter")
                return
            }

            // Reset state
            bufferLock.lock()
            pcmBuffer.removeAll()
            bufferLock.unlock()
            currentChunkIndex = 0

            // Install tap on the input node
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRunning = true

            // Start chunk rotation timer
            startChunkTimer()

            print("[AudioStreamSensor] Started recording — chunk duration: \(chunkDuration)s")
        } catch {
            print("[AudioStreamSensor] Failed to start audio engine: \(error.localizedDescription)")
        }
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

    // MARK: - Chunk Rotation

    /// Start the timer that rotates chunks at the configured interval.
    private func startChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            self?.rotateChunk()
        }
    }

    /// Finalize the current chunk and start a new one.
    private func rotateChunk() {
        guard isRunning else { return }

        // Grab the current buffer contents
        bufferLock.lock()
        let samples = pcmBuffer
        pcmBuffer.removeAll()
        bufferLock.unlock()

        guard !samples.isEmpty else { return }

        let chunkIndex = currentChunkIndex
        currentChunkIndex += 1

        // Emit a "processing" event immediately
        let processingEvent = SensingEvent(
            modality: .audio,
            payload: [
                "status": "processing",
                "chunkIndex": "\(chunkIndex)"
            ]
        )
        onEvent?(processingEvent)

        // Process the chunk asynchronously
        processingQueue.async { [weak self] in
            self?.processChunk(samples: samples, chunkIndex: chunkIndex)
        }
    }

    /// Finalize any remaining audio when stopping.
    private func finalizeCurrentChunk() {
        bufferLock.lock()
        let samples = pcmBuffer
        pcmBuffer.removeAll()
        bufferLock.unlock()

        guard !samples.isEmpty else { return }

        let chunkIndex = currentChunkIndex

        processingQueue.async { [weak self] in
            self?.processChunk(samples: samples, chunkIndex: chunkIndex)
        }
    }

    // MARK: - WAV File Creation

    /// Create a WAV file from raw Int16 PCM samples.
    /// Returns the URL of the temporary WAV file.
    private func createWAVFile(from samples: [Int16]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "audiostream_chunk_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let dataSize = samples.count * MemoryLayout<Int16>.size
        let fileSize = 44 + dataSize  // WAV header is 44 bytes

        var header = Data()

        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)

        // fmt sub-chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // Sub-chunk size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // PCM format
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channelCount).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        let byteRate = UInt32(sampleRate) * UInt32(channelCount) * 2  // 16-bit = 2 bytes
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        let blockAlign = UInt16(channelCount) * 2
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // Bits per sample

        // data sub-chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Combine header + PCM data
        var fileData = header
        samples.withUnsafeBufferPointer { ptr in
            fileData.append(UnsafeBufferPointer(start: UnsafeRawPointer(ptr.baseAddress!).assumingMemoryBound(to: UInt8.self), count: dataSize))
        }

        do {
            try fileData.write(to: fileURL)
            return fileURL
        } catch {
            print("[AudioStreamSensor] Failed to write WAV file: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Server Communication

    /// Process a completed chunk: create WAV, upload to server, emit result event.
    private func processChunk(samples: [Int16], chunkIndex: Int) {
        guard let wavURL = createWAVFile(from: samples) else {
            print("[AudioStreamSensor] Failed to create WAV for chunk \(chunkIndex)")
            return
        }

        // Clean up the temp file when done
        defer {
            try? FileManager.default.removeItem(at: wavURL)
        }

        // Read the WAV file data
        guard let wavData = try? Data(contentsOf: wavURL) else {
            print("[AudioStreamSensor] Failed to read WAV file for chunk \(chunkIndex)")
            return
        }

        // Upload to diarization server
        let endpoint = "\(Self.diarizationBaseURL)/process"
        guard let url = URL(string: endpoint) else {
            print("[AudioStreamSensor] Invalid diarization URL: \(endpoint)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // Diarization can take 10-30s
        request.httpBody = wavData

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            responseData = data
            responseError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = responseError {
            print("[AudioStreamSensor] Server request failed for chunk \(chunkIndex): \(error.localizedDescription)")
            // Emit error event
            let errorEvent = SensingEvent(
                modality: .audio,
                payload: [
                    "status": "error",
                    "chunkIndex": "\(chunkIndex)",
                    "error": error.localizedDescription
                ]
            )
            onEvent?(errorEvent)
            return
        }

        guard let data = responseData else {
            print("[AudioStreamSensor] No response data for chunk \(chunkIndex)")
            return
        }

        // Parse JSON response
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[AudioStreamSensor] Invalid JSON response for chunk \(chunkIndex)")
                return
            }

            let transcript = json["transcript"] as? String ?? ""
            let processingTime = json["processing_time"] as? Double ?? 0

            // Extract speaker names from the speakers dictionary
            var speakerNames: [String] = []
            if let speakers = json["speakers"] as? [String: [String: Any]] {
                for (_, info) in speakers {
                    if let identifiedAs = info["identified_as"] as? String {
                        speakerNames.append(identifiedAs)
                    }
                }
            }

            // Count segments
            let segments = json["segments"] as? [[String: Any]] ?? []
            let segmentCount = segments.count

            // Emit completed event with full results
            let resultEvent = SensingEvent(
                modality: .audio,
                payload: [
                    "status": "completed",
                    "transcript": transcript,
                    "speakers": speakerNames.joined(separator: ", "),
                    "segmentCount": "\(segmentCount)",
                    "processingTime": String(format: "%.1f", processingTime),
                    "chunkIndex": "\(chunkIndex)"
                ]
            )
            onEvent?(resultEvent)

            print("[AudioStreamSensor] Chunk \(chunkIndex) processed: \(segmentCount) segments, \(speakerNames.count) speakers, \(String(format: "%.1f", processingTime))s")

        } catch {
            print("[AudioStreamSensor] Failed to parse response for chunk \(chunkIndex): \(error.localizedDescription)")
        }
    }
}
