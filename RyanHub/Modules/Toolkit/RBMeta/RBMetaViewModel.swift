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
    var selectedResolution: Int = 0  // 0=low, 1=medium, 2=high

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

    // BOBO integration — auto-capture snapshots to timeline
    private var lastSnapshotTime: Date = .distantPast
    private var photoDataListenerToken: AnyListenerToken?
    /// Interval between automatic snapshots saved to BOBO timeline (seconds).
    private static let snapshotInterval: TimeInterval = 30

    // MARK: - Lifecycle

    func setupDAT(wearables: WearablesInterface) {
        self.wearables = wearables
        self.isRegistered = wearables.registrationState == .registered
        self.isRegistering = wearables.registrationState == .registering

        let selector = AutoDeviceSelector(wearables: wearables)
        self.deviceSelector = selector
        rebuildStreamSession()

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
    }

    /// Map selectedResolution index to DAT SDK enum.
    private var datResolution: StreamingResolution {
        switch selectedResolution {
        case 1: return .medium
        case 2: return .high
        default: return .low
        }
    }

    /// Resolution display label.
    static let resolutionLabels = ["Low (360p)", "Med (504p)", "High (720p)"]

    /// Rebuild the stream session with the current resolution setting.
    /// Safe to call before streaming starts; no-op effect on active stream.
    func rebuildStreamSession() {
        guard let deviceSelector else { return }
        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: datResolution,
            frameRate: 24
        )
        streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
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
                self.autoSnapshotIfNeeded(image: image)
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
                    self.autoSnapshotIfNeeded(image: image)
                }
            }
        }

        photoDataListenerToken = streamSession.photoDataPublisher.listen { [weak self] photoData in
            Task { @MainActor [weak self] in
                guard let self, let image = UIImage(data: photoData.data) else { return }
                self.saveFrameToBoboTimeline(image: image, source: "rb_meta_glasses_capture")
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

    // MARK: - BOBO Timeline Integration

    /// Called for every video frame — saves a snapshot to BOBO timeline at a fixed interval.
    private func autoSnapshotIfNeeded(image: UIImage) {
        guard isStreaming else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSnapshotTime) >= Self.snapshotInterval else { return }
        lastSnapshotTime = now
        saveFrameToBoboTimeline(image: image, source: streamingMode == .glasses ? "rb_meta_glasses" : "rb_meta_iphone")
    }

    /// Save a photo from glasses capturePhoto to BOBO timeline.
    func captureGlassesPhoto() {
        streamSession?.capturePhoto(format: .jpeg)
    }

    /// Save an image frame to the BOBO timeline and upload to iMac.
    private func saveFrameToBoboTimeline(image: UIImage, source: String) {
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }

        let event = SensingEvent(
            modality: .photo,
            payload: [:]
        )

        // Save to BOBO photos directory
        let photosDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bobo/photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        let fileURL = photosDir.appendingPathComponent("\(event.id.uuidString).jpg")
        try? jpegData.write(to: fileURL)

        var mutableEvent = event
        mutableEvent.payload["imageFileId"] = event.id.uuidString
        mutableEvent.payload["source"] = source

        // Record in BOBO timeline
        SensingEngine.shared.recordEvent(mutableEvent)

        // Upload to iMac in background
        Task.detached(priority: .utility) {
            await Self.uploadPhotoToServer(jpegData: jpegData, eventId: event.id.uuidString, source: source)
        }
    }

    /// Upload photo JPEG to bridge server for iMac storage.
    static func uploadPhotoToServer(jpegData: Data, eventId: String, source: String) async {
        let baseURL = UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
        guard let url = URL(string: "\(baseURL)/bobo/photos/upload") else { return }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()
        // Event ID field
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"event_id\"\r\n\r\n\(eventId)\r\n".data(using: .utf8)!)
        // Source field
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"source\"\r\n\r\n\(source)\r\n".data(using: .utf8)!)
        // JPEG file
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"\(eventId).jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                print("[RBMeta] Photo \(eventId) uploaded to iMac")
            }
        } catch {
            print("[RBMeta] Photo upload failed: \(error.localizedDescription)")
        }
    }
}
