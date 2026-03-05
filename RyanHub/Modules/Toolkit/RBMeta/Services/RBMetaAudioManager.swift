import AVFoundation
import Foundation

class RBMetaAudioManager {
    var onAudioCaptured: ((Data) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isCapturing = false

    private let outputFormat: AVAudioFormat

    private let sendQueue = DispatchQueue(label: "rbmeta.audio.accumulator")
    private var accumulatedData = Data()
    private let minSendBytes = 3200  // 100ms at 16kHz mono Int16

    init() {
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: RBMetaConfig.outputAudioSampleRate,
            channels: RBMetaConfig.audioChannels,
            interleaved: true
        )!
    }

    func setupAudioSession(useIPhoneMode: Bool = false) throws {
        let session = AVAudioSession.sharedInstance()
        let mode: AVAudioSession.Mode = useIPhoneMode ? .voiceChat : .videoChat
        try session.setCategory(
            .playAndRecord,
            mode: mode,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setPreferredSampleRate(RBMetaConfig.inputAudioSampleRate)
        try session.setPreferredIOBufferDuration(0.064)
        try session.setActive(true)
    }

    func startCapture() throws {
        guard !isCapturing else { return }

        audioEngine.attach(playerNode)
        let playerFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: RBMetaConfig.outputAudioSampleRate,
            channels: RBMetaConfig.audioChannels,
            interleaved: false
        )!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playerFormat)

        let inputNode = audioEngine.inputNode
        let inputNativeFormat = inputNode.outputFormat(forBus: 0)

        let needsResample = inputNativeFormat.sampleRate != RBMetaConfig.inputAudioSampleRate
            || inputNativeFormat.channelCount != RBMetaConfig.audioChannels

        sendQueue.async { self.accumulatedData = Data() }

        var converter: AVAudioConverter?
        if needsResample {
            let resampleFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: RBMetaConfig.inputAudioSampleRate,
                channels: RBMetaConfig.audioChannels,
                interleaved: false
            )!
            converter = AVAudioConverter(from: inputNativeFormat, to: resampleFormat)
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputNativeFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let pcmData: Data

            if let converter {
                let resampleFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: RBMetaConfig.inputAudioSampleRate,
                    channels: RBMetaConfig.audioChannels,
                    interleaved: false
                )!
                guard let resampled = self.convertBuffer(buffer, using: converter, targetFormat: resampleFormat) else {
                    return
                }
                pcmData = self.float32BufferToInt16Data(resampled)
            } else {
                pcmData = self.float32BufferToInt16Data(buffer)
            }

            self.sendQueue.async {
                self.accumulatedData.append(pcmData)
                if self.accumulatedData.count >= self.minSendBytes {
                    let chunk = self.accumulatedData
                    self.accumulatedData = Data()
                    self.onAudioCaptured?(chunk)
                }
            }
        }

        try audioEngine.start()
        playerNode.play()
        isCapturing = true
    }

    func playAudio(data: Data) {
        guard isCapturing, !data.isEmpty else { return }

        let playerFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: RBMetaConfig.outputAudioSampleRate,
            channels: RBMetaConfig.audioChannels,
            interleaved: false
        )!

        let frameCount = UInt32(data.count) / (RBMetaConfig.audioBitsPerSample / 8 * RBMetaConfig.audioChannels)
        guard frameCount > 0 else { return }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: playerFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let floatData = buffer.floatChannelData else { return }
        data.withUnsafeBytes { rawBuffer in
            guard let int16Ptr = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }
            for i in 0..<Int(frameCount) {
                floatData[0][i] = Float(int16Ptr[i]) / Float(Int16.max)
            }
        }

        playerNode.scheduleBuffer(buffer)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func stopPlayback() {
        playerNode.stop()
        playerNode.play()
    }

    func stopCapture() {
        guard isCapturing else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        audioEngine.stop()
        audioEngine.detach(playerNode)
        isCapturing = false
        sendQueue.async {
            if !self.accumulatedData.isEmpty {
                let chunk = self.accumulatedData
                self.accumulatedData = Data()
                self.onAudioCaptured?(chunk)
            }
        }
    }

    // MARK: - Private helpers

    private func float32BufferToInt16Data(_ buffer: AVAudioPCMBuffer) -> Data {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, let floatData = buffer.floatChannelData else { return Data() }
        var int16Array = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let sample = max(-1.0, min(1.0, floatData[0][i]))
            int16Array[i] = Int16(sample * Float(Int16.max))
        }
        return int16Array.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
    }

    private func convertBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCount = UInt32(Double(inputBuffer.frameLength) * ratio)
        guard outputFrameCount > 0 else { return nil }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            return nil
        }

        var error: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if error != nil { return nil }
        return outputBuffer
    }
}
