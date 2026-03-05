import Foundation
import SwiftUI
import MWDATCamera
import MWDATCore

enum RBMetaStreamingMode: String {
    case glasses
    case iPhone
}

enum RBMetaStreamingStatus {
    case stopped
    case waiting
    case streaming
}

@Observable
@MainActor
final class RBMetaViewModel {
    // MARK: - Public state

    // Session
    var isGeminiActive: Bool = false
    var geminiConnectionState: RBGeminiConnectionState = .disconnected
    var isModelSpeaking: Bool = false
    var errorMessage: String?

    // Transcripts
    var userTranscript: String = ""
    var aiTranscript: String = ""

    // Tool calls
    var toolCallStatus: RBToolCallStatus = .idle
    var openClawConnectionState: RBOpenClawConnectionState = .notConfigured

    // Streaming
    var currentVideoFrame: UIImage?
    var hasReceivedFirstFrame: Bool = false
    var streamingStatus: RBMetaStreamingStatus = .stopped
    var streamingMode: RBMetaStreamingMode = .glasses
    var hasActiveDevice: Bool = false

    // DAT Registration
    var isRegistering: Bool = false
    var isRegistered: Bool = false

    var isStreaming: Bool { streamingStatus != .stopped }

    // MARK: - Private services

    private let geminiService = RBGeminiService()
    private let openClawBridge = RBOpenClawBridge()
    private var toolCallRouter: RBToolCallRouter?
    private let audioManager = RBMetaAudioManager()
    private var lastVideoFrameTime: Date = .distantPast
    private var stateObservation: Task<Void, Never>?

    // DAT SDK
    private var streamSession: StreamSession?
    private var wearables: WearablesInterface?
    private var deviceSelector: AutoDeviceSelector?
    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var deviceMonitorTask: Task<Void, Never>?
    private var registrationTask: Task<Void, Never>?

    // iPhone camera
    private var cameraManager: RBMetaCameraManager?

    // MARK: - Lifecycle

    func setupDAT(wearables: WearablesInterface) {
        self.wearables = wearables
        self.isRegistered = wearables.registrationState == .registered
        self.isRegistering = wearables.registrationState == .registering

        let selector = AutoDeviceSelector(wearables: wearables)
        self.deviceSelector = selector
        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: StreamingResolution.low,
            frameRate: 24
        )
        self.streamSession = StreamSession(streamSessionConfig: config, deviceSelector: selector)

        deviceMonitorTask = Task { @MainActor in
            for await device in selector.activeDeviceStream() {
                self.hasActiveDevice = device != nil
            }
        }

        registrationTask = Task { @MainActor in
            for await state in wearables.registrationStateStream() {
                self.isRegistered = state == .registered
                self.isRegistering = state == .registering
            }
        }

        attachDATListeners()
    }

    // MARK: - DAT Registration

    func connectGlasses() {
        guard let wearables, !isRegistering else { return }
        Task {
            do {
                try await wearables.startRegistration()
            } catch {
                errorMessage = "Registration failed: \(error.localizedDescription)"
            }
        }
    }

    func disconnectGlasses() {
        guard let wearables else { return }
        Task {
            do {
                try await wearables.startUnregistration()
            } catch {
                errorMessage = "Disconnect failed: \(error.localizedDescription)"
            }
        }
    }

    func handleDATCallback(url: URL) async {
        do {
            _ = try await Wearables.shared.handleUrl(url)
        } catch {
            errorMessage = "Registration callback error: \(error.localizedDescription)"
        }
    }

    // MARK: - Gemini Session

    func startGeminiSession() async {
        guard !isGeminiActive else { return }

        guard RBMetaConfig.isConfigured else {
            errorMessage = "Gemini API key not configured"
            return
        }

        isGeminiActive = true

        // Wire audio
        audioManager.onAudioCaptured = { [weak self] data in
            guard let self else { return }
            Task { @MainActor in
                if self.streamingMode == .iPhone && self.geminiService.isModelSpeaking { return }
                self.geminiService.sendAudio(data: data)
            }
        }

        geminiService.onAudioReceived = { [weak self] data in
            self?.audioManager.playAudio(data: data)
        }

        geminiService.onInterrupted = { [weak self] in
            self?.audioManager.stopPlayback()
        }

        geminiService.onTurnComplete = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.userTranscript = ""
            }
        }

        geminiService.onInputTranscription = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in
                self.userTranscript += text
                self.aiTranscript = ""
            }
        }

        geminiService.onOutputTranscription = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in
                self.aiTranscript += text
            }
        }

        geminiService.onDisconnected = { [weak self] reason in
            guard let self else { return }
            Task { @MainActor in
                guard self.isGeminiActive else { return }
                self.stopGeminiSession()
                self.errorMessage = "Connection lost: \(reason ?? "Unknown error")"
            }
        }

        // OpenClaw
        await openClawBridge.checkConnection()
        openClawBridge.resetSession()

        toolCallRouter = RBToolCallRouter(bridge: openClawBridge)

        geminiService.onToolCall = { [weak self] toolCall in
            guard let self else { return }
            Task { @MainActor in
                for call in toolCall.functionCalls {
                    self.toolCallRouter?.handleToolCall(call) { [weak self] response in
                        self?.geminiService.sendToolResponse(response)
                    }
                }
            }
        }

        geminiService.onToolCallCancellation = { [weak self] cancellation in
            guard let self else { return }
            Task { @MainActor in
                self.toolCallRouter?.cancelToolCalls(ids: cancellation.ids)
            }
        }

        // State observation
        stateObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { break }
                self.geminiConnectionState = self.geminiService.connectionState
                self.isModelSpeaking = self.geminiService.isModelSpeaking
                self.toolCallStatus = self.openClawBridge.lastToolCallStatus
                self.openClawConnectionState = self.openClawBridge.connectionState
            }
        }

        // Audio setup
        do {
            try audioManager.setupAudioSession(useIPhoneMode: streamingMode == .iPhone)
        } catch {
            errorMessage = "Audio setup failed: \(error.localizedDescription)"
            isGeminiActive = false
            return
        }

        // Connect
        let setupOk = await geminiService.connect()

        if !setupOk {
            let msg: String
            if case .error(let err) = geminiService.connectionState {
                msg = err
            } else {
                msg = "Failed to connect to Gemini"
            }
            errorMessage = msg
            geminiService.disconnect()
            stateObservation?.cancel()
            stateObservation = nil
            isGeminiActive = false
            geminiConnectionState = .disconnected
            return
        }

        // Start mic
        do {
            try audioManager.startCapture()
        } catch {
            errorMessage = "Mic capture failed: \(error.localizedDescription)"
            geminiService.disconnect()
            stateObservation?.cancel()
            stateObservation = nil
            isGeminiActive = false
            geminiConnectionState = .disconnected
            return
        }
    }

    func stopGeminiSession() {
        toolCallRouter?.cancelAll()
        toolCallRouter = nil
        audioManager.stopCapture()
        geminiService.disconnect()
        stateObservation?.cancel()
        stateObservation = nil
        isGeminiActive = false
        geminiConnectionState = .disconnected
        isModelSpeaking = false
        userTranscript = ""
        aiTranscript = ""
        toolCallStatus = .idle
    }

    // MARK: - Video Streaming

    func startGlassesStreaming() async {
        guard let wearables else {
            errorMessage = "DAT SDK not initialized"
            return
        }

        streamingMode = .glasses
        let permission = Permission.camera
        do {
            let status = try await wearables.checkPermissionStatus(permission)
            if status == .granted {
                await streamSession?.start()
                return
            }
            let requestStatus = try await wearables.requestPermission(permission)
            if requestStatus == .granted {
                await streamSession?.start()
                return
            }
            errorMessage = "Permission denied"
        } catch {
            errorMessage = "Permission error: \(error.description)"
        }
    }

    func startIPhoneCamera() async {
        let granted = await RBMetaCameraManager.requestPermission()
        guard granted else {
            errorMessage = "Camera permission denied. Grant access in Settings."
            return
        }

        streamingMode = .iPhone
        let camera = RBMetaCameraManager()
        camera.onFrameCaptured = { [weak self] image in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentVideoFrame = image
                if !self.hasReceivedFirstFrame {
                    self.hasReceivedFirstFrame = true
                }
                self.sendVideoFrameIfThrottled(image: image)
            }
        }
        camera.start()
        cameraManager = camera
        streamingStatus = .streaming
    }

    func stopStreaming() async {
        if streamingMode == .iPhone {
            cameraManager?.stop()
            cameraManager = nil
            currentVideoFrame = nil
            hasReceivedFirstFrame = false
            streamingStatus = .stopped
            streamingMode = .glasses
        } else {
            await streamSession?.stop()
        }
    }

    func stopAll() async {
        stopGeminiSession()
        await stopStreaming()
    }

    // MARK: - Private

    private func sendVideoFrameIfThrottled(image: UIImage) {
        guard isGeminiActive, geminiConnectionState == .ready else { return }
        let now = Date()
        guard now.timeIntervalSince(lastVideoFrameTime) >= RBMetaConfig.videoFrameInterval else { return }
        lastVideoFrameTime = now
        geminiService.sendVideoFrame(image: image)
    }

    private func attachDATListeners() {
        guard let streamSession else { return }

        stateListenerToken = streamSession.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .stopped:
                    self.currentVideoFrame = nil
                    self.streamingStatus = .stopped
                case .waitingForDevice, .starting, .stopping, .paused:
                    self.streamingStatus = .waiting
                case .streaming:
                    self.streamingStatus = .streaming
                }
            }
        }

        videoFrameListenerToken = streamSession.videoFramePublisher.listen { [weak self] videoFrame in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let image = videoFrame.makeUIImage() {
                    self.currentVideoFrame = image
                    if !self.hasReceivedFirstFrame {
                        self.hasReceivedFirstFrame = true
                    }
                    self.sendVideoFrameIfThrottled(image: image)
                }
            }
        }

        errorListenerToken = streamSession.errorPublisher.listen { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.streamingStatus == .stopped {
                    if case .deviceNotConnected = error { return }
                    if case .deviceNotFound = error { return }
                }
                self.errorMessage = self.formatStreamingError(error)
            }
        }
    }

    private func formatStreamingError(_ error: StreamSessionError) -> String {
        switch error {
        case .internalError:
            return "An internal error occurred. Please try again."
        case .deviceNotFound:
            return "Device not found. Ensure your glasses are connected."
        case .deviceNotConnected:
            return "Device not connected. Check your connection."
        case .timeout:
            return "The operation timed out. Please try again."
        case .videoStreamingError:
            return "Video streaming failed. Please try again."
        case .audioStreamingError:
            return "Audio streaming failed. Please try again."
        case .permissionDenied:
            return "Camera permission denied."
        case .hingesClosed:
            return "Glasses hinges are closed. Please open them."
        @unknown default:
            return "An unknown streaming error occurred."
        }
    }
}
