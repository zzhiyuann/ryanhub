import Foundation
import SwiftUI
import AVFoundation
import PhotosUI

/// ViewModel for the Chat module. Manages messages, WebSocket communication,
/// image/voice input, and chat state.
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isTyping: Bool = false
    var isConnected: Bool = false
    var connectionState: WebSocketClient.ConnectionState = .disconnected
    var connectionError: String?

    /// Trigger incremented on every message mutation to force view refresh.
    var messageUpdateTrigger: Int = 0

    // MARK: - Image Picker State

    var showImagePicker: Bool = false
    var showCamera: Bool = false
    var selectedPhotoItem: PhotosPickerItem?

    // MARK: - Voice Recording State

    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0

    // MARK: - Private

    private let webSocket = WebSocketClient()
    private var currentStreamingMessageId: String?
    private var serverURL: String?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private weak var appState: AppState?
    private var statePollingTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        messages = ChatMessage.loadSaved()
        setupWebSocketCallbacks()
    }

    // MARK: - Public API

    /// Connect to the Dispatcher WebSocket.
    func connect(to url: String, appState: AppState? = nil) {
        serverURL = url
        if let appState { self.appState = appState }
        webSocket.connect(to: url)
        startStatePolling()
    }

    /// Disconnect from the Dispatcher.
    func disconnect() {
        statePollingTask?.cancel()
        statePollingTask = nil
        webSocket.disconnect()
        syncStateToAppState()
    }

    /// Retry connection to the Dispatcher.
    func retry() {
        guard let url = serverURL else { return }
        webSocket.connect(to: url)
        startStatePolling()
    }

    /// Send the current input text as a message.
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage.user(text)
        appendMessage(userMessage)
        inputText = ""
        isTyping = true

        let messageId = userMessage.id

        Task {
            do {
                try await webSocket.sendMessage(id: messageId, content: text)
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    let errorMessage = ChatMessage.assistant("Failed to send message: \(error.localizedDescription)")
                    self.appendMessage(errorMessage)
                    self.saveMessages()
                }
            }
        }
    }

    /// Send an image message from photo picker data.
    func sendImageMessage(data: Data) {
        let base64 = data.base64EncodedString()
        let userMessage = ChatMessage.userImage(base64: base64)
        appendMessage(userMessage)
        isTyping = true

        let messageId = userMessage.id

        Task {
            do {
                try await webSocket.sendImageMessage(id: messageId, imageBase64: base64)
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    let errorMessage = ChatMessage.assistant("Failed to send image: \(error.localizedDescription)")
                    self.appendMessage(errorMessage)
                    self.saveMessages()
                }
            }
        }
    }

    /// Handle photo picker selection.
    func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.sendImageMessage(data: data)
                }
            }
        }
    }

    // MARK: - Voice Recording

    /// Start recording voice.
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_\(UUID().uuidString).m4a"
        let url = tempDir.appendingPathComponent(fileName)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0

            // Update duration periodically on the main actor
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
            recordingTimer = timer
        } catch {
            // Recording failed silently
        }
    }

    /// Stop recording and send the voice message.
    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else {
            return
        }

        let duration = recordingDuration
        guard duration >= 0.5 else {
            // Too short, discard
            recordingDuration = 0
            return
        }

        let base64 = data.base64EncodedString()
        let userMessage = ChatMessage.userVoice(base64: base64, duration: duration)
        appendMessage(userMessage)
        isTyping = true
        recordingDuration = 0

        let messageId = userMessage.id

        Task {
            do {
                try await webSocket.sendVoiceMessage(id: messageId, audioBase64: base64, duration: duration)
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    let errorMessage = ChatMessage.assistant("Failed to send voice message: \(error.localizedDescription)")
                    self.appendMessage(errorMessage)
                    self.saveMessages()
                }
            }
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: url)
    }

    /// Cancel recording without sending.
    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false
        recordingDuration = 0

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Clear all chat history.
    func clearHistory() {
        messages.removeAll()
        messageUpdateTrigger += 1
        ChatMessage.clearSaved()
    }

    // MARK: - Private

    /// Append a message and notify the view.
    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        messageUpdateTrigger += 1
        saveMessages()
    }

    private func setupWebSocketCallbacks() {
        webSocket.onConnectionChange = { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = connected
                self.connectionState = self.webSocket.connectionState
                if !connected {
                    self.connectionError = self.webSocket.lastError
                } else {
                    self.connectionError = nil
                }
                self.syncStateToAppState()
            }
        }

        webSocket.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleDispatcherMessage(message)
            }
        }
    }

    /// Sync local connection state to the shared AppState so Settings and other views see it.
    private func syncStateToAppState() {
        appState?.isConnected = isConnected
        appState?.connectionState = connectionState
        appState?.connectionError = connectionError
    }

    /// Poll WebSocketClient.connectionState to catch intermediate states
    /// (.connecting, .reconnecting) that don't trigger onConnectionChange.
    private func startStatePolling() {
        statePollingTask?.cancel()
        statePollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { break }
                await MainActor.run {
                    let wsState = self.webSocket.connectionState
                    if self.connectionState != wsState {
                        self.connectionState = wsState
                        self.connectionError = self.webSocket.lastError
                        self.syncStateToAppState()
                    }
                }
                // Stop polling once connection is stable (connected or failed past max retries)
                let currentState = await MainActor.run { self.connectionState }
                if case .connected = currentState { break }
                if case .failed = currentState { break }
                if case .disconnected = currentState { break }
            }
        }
    }

    private func handleDispatcherMessage(_ message: DispatcherMessage) {
        switch message.type {
        case "response":
            handleResponseMessage(message)
        case "status":
            // Status messages update connection info
            if let connected = message.connected {
                isConnected = connected
            }
        case "error":
            isTyping = false
            if let errorText = message.message {
                let errorMessage = ChatMessage.assistant("Error: \(errorText)")
                appendMessage(errorMessage)
            }
        default:
            break
        }
    }

    private func handleResponseMessage(_ message: DispatcherMessage) {
        guard let content = message.content, let id = message.id else { return }

        let isStreaming = message.streaming ?? false

        if let existingIndex = messages.firstIndex(where: { $0.id == id && $0.role == .assistant }) {
            // Update existing streaming message in place
            messages[existingIndex] = ChatMessage(
                id: id,
                content: content,
                role: .assistant,
                timestamp: messages[existingIndex].timestamp,
                isStreaming: isStreaming
            )
            // Force view update for streaming content changes
            messageUpdateTrigger += 1
        } else {
            // New assistant message — always appended at the end
            let assistantMessage = ChatMessage.assistant(content, id: id, isStreaming: isStreaming)
            messages.append(assistantMessage)
            messageUpdateTrigger += 1
        }

        if !isStreaming {
            isTyping = false
            currentStreamingMessageId = nil
            saveMessages()
        } else {
            currentStreamingMessageId = id
        }
    }

    private func saveMessages() {
        ChatMessage.save(messages)
    }
}
