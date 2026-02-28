import Foundation
import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

/// ViewModel for the Chat module. Manages messages, WebSocket communication,
/// image/voice input, and chat state. Single-chat flow (no multi-session).
@MainActor
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

    /// Per-message status tracking for concurrent message handling.
    /// Maps user message ID -> current status.
    var messageStatuses: [String: MessageStatus] = [:]

    /// Status of an individual message in the pipeline.
    enum MessageStatus: Equatable {
        case sending           // Message sent, waiting for ack
        case acknowledged      // Server received
        case processing        // Server is generating response
        case done              // Final response received
        case failed(String)    // Error
    }

    // MARK: - Image Picker State

    var showImagePicker: Bool = false
    var showCamera: Bool = false
    var selectedPhotoItem: PhotosPickerItem?

    /// Image data waiting to be sent alongside a text message.
    /// Set when the user picks a photo; cleared after sending or dismissal.
    var pendingImageData: Data?

    // MARK: - Voice Recording State

    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0
    /// Real-time audio level samples for waveform visualization (0.0 to 1.0).
    /// New samples are appended during recording; the waveform view reads the tail.
    var audioLevels: [CGFloat] = []

    // MARK: - AskUserQuestion State

    /// The question text from the agent's AskUserQuestion tool call.
    var pendingQuestion: String?
    /// Option buttons for the pending question.
    var pendingQuestionOptions: [String] = []
    /// The message ID associated with the pending question.
    var pendingQuestionMessageId: String?
    /// The session ID prefix for routing the answer back.
    var pendingQuestionSessionId: String?
    /// Whether free-text answers are allowed for the pending question.
    var pendingQuestionAllowFreeText: Bool = true

    // MARK: - Notification Integration

    /// Reference to the notification manager for sending local push notifications.
    @ObservationIgnored weak var notificationManager: NotificationManager?

    /// Reference to AppState for checking foreground/background and tab state.
    @ObservationIgnored weak var appStateRef: AppState?

    /// Whether the user is currently viewing the chat tab.
    @ObservationIgnored var isUserOnChatTab: Bool = true

    // MARK: - Private

    private let webSocket = WebSocketClient()
    /// The ID of the currently streaming assistant message, if any.
    /// Used by the view to suppress the standalone TypingIndicator when
    /// a streaming message bubble is already visible.
    private(set) var currentStreamingMessageId: String?
    private var serverURL: String?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private weak var appState: AppState?
    private var statePollingTask: Task<Void, Never>?

    /// Maps user message ID -> when the message was sent (for progress phases).
    private var messageSendTimes: [String: Date] = [:]

    /// Background task identifier for keeping the app alive while awaiting a response.
    @ObservationIgnored private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Timer that periodically triggers UI updates while messages are pending,
    /// so the progress phase text refreshes as time elapses.
    private var progressTimer: Timer?

    /// Progress phase descriptions based on elapsed time since a message was sent.
    private static let progressPhases: [(TimeInterval, String)] = [
        (5, "Received, processing..."),
        (30, "Analyzing task..."),
        (60, "Reading code..."),
        (120, "Writing changes..."),
        (180, "Still running... complex task"),
        (300, "Running for a while, hang tight"),
    ]

    // MARK: - Init

    init() {
        ChatMessage.migrateFromMultiSession()
        messages = ChatMessage.loadSaved()
        setupWebSocketCallbacks()
        // Sync from bridge server (source of truth for cross-device sync)
        Task { @MainActor [weak self] in
            if let serverMessages = await ChatMessage.loadFromServer(), !serverMessages.isEmpty {
                // Restore image data from disk for messages that have it
                let restored = serverMessages.map { msg -> ChatMessage in
                    var m = msg
                    if m.hasImageOnDisk && m.imageBase64 == nil,
                       let imageData = ChatMessage.loadImageFromDisk(messageId: m.id) {
                        m.imageBase64 = imageData.base64EncodedString()
                    }
                    return m
                }
                self?.messages = restored
            }
        }
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

    /// Called when the app returns to foreground. Re-establishes connection
    /// if it was lost while suspended in the background.
    func ensureConnected() {
        webSocket.reconnectIfNeeded()
        startStatePolling()
    }

    /// Send the current input text (and any pending image) as a message.
    /// Optionally include a reference to a message being replied to.
    func sendMessage(replyingTo: ChatMessage? = nil) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If there's a pending image, send it with the optional caption text.
        if let imageData = pendingImageData {
            sendImageMessage(data: imageData, caption: text, replyingTo: replyingTo)
            inputText = ""
            pendingImageData = nil
            return
        }

        guard !text.isEmpty else { return }

        // Handle slash commands. Some have local-side effects (e.g. /new clears
        // the chat), but recognized commands are still sent to the Dispatcher
        // as regular messages — the Dispatcher's _classify() parses /commands and
        // @model prefixes from message content. Returns true if fully handled.
        if text.hasPrefix("/") {
            if handleSlashCommand(text) {
                return
            }
        }

        let replyPreview = replyingTo.map { Self.buildReplyPreview(for: $0) }
        let userMessage = ChatMessage(
            content: text,
            role: .user,
            replyToId: replyingTo?.id,
            replyToPreview: replyPreview
        )
        appendMessage(userMessage)
        inputText = ""

        let messageId = userMessage.id
        messageStatuses[messageId] = .sending
        messageSendTimes[messageId] = Date()
        isTyping = true
        startProgressTimer()

        // Build the content to send over the wire. If the message matches any
        // personal toolkit (health, parking, vocab, calendar, books), prepend
        // relevant context so the AI can answer personal questions.
        var contentToSend = Self.buildContentWithContext(userText: text)

        // Prepend language instruction so the AI responds in the user's chosen language.
        let language = appState?.language ?? .english
        contentToSend = "\(language.responseLanguageInstruction)\n\n\(contentToSend)"

        let languageCode = language.rawValue

        Task {
            do {
                try await webSocket.sendMessage(id: messageId, content: contentToSend, language: languageCode)
            } catch {
                self.messageStatuses[messageId] = .failed(error.localizedDescription)
                self.updateGlobalTypingState()
                let errorMessage = ChatMessage.assistant("Failed to send message: \(error.localizedDescription)")
                self.appendMessage(errorMessage)
                self.saveMessages()
            }
        }
    }

    /// Send an image message from photo picker data, with an optional user caption.
    func sendImageMessage(data: Data, caption: String = "", replyingTo: ChatMessage? = nil) {
        let base64 = data.base64EncodedString()
        let replyPreview = replyingTo.map { Self.buildReplyPreview(for: $0) }
        let userMessage = ChatMessage(
            content: caption,
            role: .user,
            imageBase64: base64,
            replyToId: replyingTo?.id,
            replyToPreview: replyPreview
        )
        appendMessage(userMessage)

        let messageId = userMessage.id
        messageStatuses[messageId] = .sending
        messageSendTimes[messageId] = Date()
        isTyping = true
        startProgressTimer()

        let language = appState?.language ?? .english
        let languageCode = language.rawValue

        // Build the wire caption: user caption (if any) + language instruction.
        var wireCaption = caption
        let langInstruction = language.responseLanguageInstruction
        if wireCaption.isEmpty {
            wireCaption = langInstruction
        } else {
            wireCaption = "\(langInstruction)\n\n\(wireCaption)"
        }

        Task {
            do {
                try await webSocket.sendImageMessage(
                    id: messageId,
                    imageBase64: base64,
                    caption: wireCaption,
                    language: languageCode
                )
            } catch {
                self.messageStatuses[messageId] = .failed(error.localizedDescription)
                self.updateGlobalTypingState()
                let errorMessage = ChatMessage.assistant("Failed to send image: \(error.localizedDescription)")
                self.appendMessage(errorMessage)
                self.saveMessages()
            }
        }
    }

    /// Handle photo picker selection.
    /// Loads image data from the PhotosPickerItem, converts through UIImage
    /// to normalize the format, then stores as pending image for the user to
    /// add a caption before sending.
    func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let jpegData = uiImage.jpegData(compressionQuality: 0.7) {
                self.pendingImageData = jpegData
            }
        }
    }

    /// Clear the pending image attachment without sending.
    func clearPendingImage() {
        pendingImageData = nil
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
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0
            audioLevels = []

            // Sample audio levels at ~30fps and update duration
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)

                // Read real audio power from the microphone
                self.audioRecorder?.updateMeters()
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                // Normalize: averagePower ranges from -160 (silence) to 0 (max).
                // Map to 0.0 – 1.0 with a floor at -50 dB for visual range.
                let clampedPower = max(power, -50)
                let normalized = CGFloat((clampedPower + 50) / 50)
                self.audioLevels.append(normalized)
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
        audioLevels = []

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
        recordingDuration = 0

        let messageId = userMessage.id
        messageStatuses[messageId] = .sending
        messageSendTimes[messageId] = Date()
        isTyping = true
        startProgressTimer()

        let language = appState?.language ?? .english
        let languageCode = language.rawValue

        Task {
            do {
                try await webSocket.sendVoiceMessage(
                    id: messageId,
                    audioBase64: base64,
                    duration: duration,
                    language: languageCode
                )
            } catch {
                self.messageStatuses[messageId] = .failed(error.localizedDescription)
                self.updateGlobalTypingState()
                let errorMessage = ChatMessage.assistant("Failed to send voice message: \(error.localizedDescription)")
                self.appendMessage(errorMessage)
                self.saveMessages()
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
        audioLevels = []

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

    // MARK: - Progress Phases

    /// Returns the current progress phase text for a pending user message,
    /// or nil if the message is not in a pending state.
    func progressText(for messageId: String) -> String? {
        guard let status = messageStatuses[messageId],
              status == .acknowledged || status == .processing,
              let sendTime = messageSendTimes[messageId] else { return nil }
        let elapsed = Date().timeIntervalSince(sendTime)
        var phase = "Processing..."
        for (threshold, text) in Self.progressPhases {
            if elapsed >= threshold { phase = text }
        }
        return phase
    }

    /// Retry a failed user message by re-sending it to the Dispatcher.
    func retryMessage(_ message: ChatMessage) {
        guard message.role == .user else { return }

        // Remove the failed status
        messageStatuses.removeValue(forKey: message.id)
        // Remove any error response that was appended for this message
        messages.removeAll { $0.id == "resp-\(message.id)" }
        messageUpdateTrigger += 1

        // Re-send
        messageStatuses[message.id] = .sending
        messageSendTimes[message.id] = Date()
        isTyping = true
        startProgressTimer()

        var contentToSend: String
        switch message.messageType {
        case .image:
            // Re-send image message
            let language = appState?.language ?? .english
            let languageCode = language.rawValue
            var wireCaption = message.content
            let langInstruction = language.responseLanguageInstruction
            if wireCaption.isEmpty {
                wireCaption = langInstruction
            } else {
                wireCaption = "\(langInstruction)\n\n\(wireCaption)"
            }
            let messageId = message.id
            Task {
                do {
                    try await webSocket.sendImageMessage(
                        id: messageId,
                        imageBase64: message.imageBase64 ?? "",
                        caption: wireCaption,
                        language: languageCode
                    )
                } catch {
                    self.messageStatuses[messageId] = .failed(error.localizedDescription)
                    self.updateGlobalTypingState()
                }
            }
            return
        case .voice:
            // Re-send voice message
            let language = appState?.language ?? .english
            let languageCode = language.rawValue
            let messageId = message.id
            Task {
                do {
                    try await webSocket.sendVoiceMessage(
                        id: messageId,
                        audioBase64: message.voiceBase64 ?? "",
                        duration: message.voiceDuration ?? 0,
                        language: languageCode
                    )
                } catch {
                    self.messageStatuses[messageId] = .failed(error.localizedDescription)
                    self.updateGlobalTypingState()
                }
            }
            return
        case .text:
            contentToSend = Self.buildContentWithContext(userText: message.content)
            let language = appState?.language ?? .english
            contentToSend = "\(language.responseLanguageInstruction)\n\n\(contentToSend)"
            let messageId = message.id
            let languageCode = language.rawValue
            Task {
                do {
                    try await webSocket.sendMessage(id: messageId, content: contentToSend, language: languageCode)
                } catch {
                    self.messageStatuses[messageId] = .failed(error.localizedDescription)
                    self.updateGlobalTypingState()
                }
            }
        }
    }

    // MARK: - Message Editing

    /// Whether a user message can be edited.
    func isMessageEditable(_ message: ChatMessage) -> Bool {
        message.role == .user && message.messageType == .text
    }

    /// Edit a previously sent message: replace it with a new message carrying
    /// the edited content, truncate all messages after it (ChatGPT-style),
    /// and re-send to get a fresh response.
    func editMessage(_ message: ChatMessage, newContent: String) {
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isMessageEditable(message) else { return }

        // Create a brand-new message ID so the dispatcher treats it as fresh
        let newId = UUID().uuidString

        // Find the edited message, replace it, and truncate everything after
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = ChatMessage(
                id: newId,
                content: trimmed,
                role: .user,
                replyToId: message.replyToId,
                replyToPreview: message.replyToPreview
            )

            // Remove all messages after this one
            if index + 1 < messages.count {
                messages.removeSubrange((index + 1)...)
            }
            messageUpdateTrigger += 1
        }

        // Set up status tracking for the new message
        messageStatuses[newId] = .sending
        messageSendTimes[newId] = Date()
        isTyping = true
        currentStreamingMessageId = nil
        startProgressTimer()

        // Send as a regular new message
        var contentToSend = Self.buildContentWithContext(userText: trimmed)
        let language = appState?.language ?? .english
        contentToSend = "\(language.responseLanguageInstruction)\n\n\(contentToSend)"
        let languageCode = language.rawValue

        Task {
            do {
                try await webSocket.sendMessage(id: newId, content: contentToSend, language: languageCode)
            } catch {
                self.messageStatuses[newId] = .failed(error.localizedDescription)
                self.updateGlobalTypingState()
                let errorMessage = ChatMessage.assistant("Failed to send message: \(error.localizedDescription)")
                self.appendMessage(errorMessage)
                self.saveMessages()
            }
        }

        saveMessages()
    }

    // MARK: - Message Deletion

    /// Delete a message from the chat history, cleaning up any associated disk resources.
    func deleteMessage(_ message: ChatMessage) {
        withAnimation(.easeOut(duration: 0.25)) {
            messages.removeAll { $0.id == message.id }
        }
        if message.hasImageOnDisk {
            ChatMessage.deleteImageFromDisk(messageId: message.id)
        }
        saveMessages()
        messageUpdateTrigger += 1
    }

    // MARK: - Slash Commands

    /// Known slash commands that the Dispatcher recognizes.
    /// Commands not in this set produce a local "unknown command" error.
    private static let knownCommands: Set<String> = [
        "/status", "/cancel", "/stop", "/history",
        "/help", "/peek", "/new", "/q", "/quick"
    ]

    /// Handle a slash command typed by the user.
    /// Returns true if the command was fully handled (caller should return early).
    /// Returns false if the text should continue through normal sendMessage flow
    /// (this happens for unknown commands that look like slash commands but aren't).
    private func handleSlashCommand(_ text: String) -> Bool {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespaces)
        let baseCommand = String(lowered.split(separator: " ").first ?? "")

        // /q (quick Q&A) has arguments — send the full text as a regular message.
        // The Dispatcher parses the /q prefix and routes to quick-answer mode.
        if baseCommand == "/q" || baseCommand == "/quick" {
            // Fall through to normal sendMessage flow — don't intercept.
            return false
        }

        // /new: clear the chat and tell the Dispatcher to force_new.
        if baseCommand == "/new" {
            let userMessage = ChatMessage.user(text)
            appendMessage(userMessage)
            inputText = ""

            // Also send to Dispatcher so it sets force_new for the next task.
            sendCommandAsMessage(text, userMessageId: userMessage.id)

            // Clear local messages to start fresh
            messages.removeAll()
            messageUpdateTrigger += 1
            ChatMessage.clearSaved()

            let systemMsg = ChatMessage.assistant("Chat cleared. Starting fresh.")
            appendMessage(systemMsg)
            return true
        }

        // Known server-side commands: send as regular message, Dispatcher handles them.
        if Self.knownCommands.contains(baseCommand) {
            let userMessage = ChatMessage.user(text)
            appendMessage(userMessage)
            inputText = ""

            sendCommandAsMessage(text, userMessageId: userMessage.id)
            return true
        }

        // Unknown command — show local error, don't send to server.
        let userMessage = ChatMessage.user(text)
        appendMessage(userMessage)
        inputText = ""

        let helpText = """
            Unknown command: \(baseCommand)
            Available: /status, /cancel, /history, /new, /peek, /help, /q <question>
            Model switch: @haiku, @sonnet, @opus (prefix your message)
            """
        let systemMsg = ChatMessage.assistant(helpText)
        appendMessage(systemMsg)
        return true
    }

    /// Send a slash command to the Dispatcher as a regular "message" type.
    /// The Dispatcher's _classify() method parses /commands from message content,
    /// so no special "command" wire type is needed.
    private func sendCommandAsMessage(_ text: String, userMessageId: String) {
        let messageId = userMessageId
        messageStatuses[messageId] = .sending
        messageSendTimes[messageId] = Date()
        isTyping = true
        startProgressTimer()

        Task {
            do {
                // Send the raw command text — no language prefix or health context
                // needed for meta-commands.
                try await webSocket.sendMessage(id: messageId, content: text)
            } catch {
                self.messageStatuses[messageId] = .failed(error.localizedDescription)
                self.updateGlobalTypingState()
                let errorMessage = ChatMessage.assistant("Failed to send command: \(error.localizedDescription)")
                self.appendMessage(errorMessage)
                self.saveMessages()
            }
        }
    }

    // MARK: - Personal Context Injection

    /// Prepend relevant personal data context (health, parking, vocab, calendar, books)
    /// to the user's message so the AI can answer personal questions without backend changes.
    /// The context is only added to the wire content — the local ChatMessage
    /// stored in the UI always shows the original user text.
    static func buildContentWithContext(userText: String) -> String {
        PersonalContext.buildContext(for: userText)
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
                    // Fix 1: Clear streaming state on disconnect.
                    // When WebSocket drops mid-stream, pending statuses would
                    // stay forever, keeping isTyping true. Force them to .done.
                    self.clearStaleStreamingState()
                } else {
                    self.connectionError = nil
                    // Fix 3: On reconnect, clean up any leftover .processing
                    // states from the previous connection that never completed.
                    self.clearStaleStreamingState()
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
                let wsState = self.webSocket.connectionState
                if self.connectionState != wsState {
                    self.connectionState = wsState
                    self.connectionError = self.webSocket.lastError
                    self.syncStateToAppState()
                }
                // Stop polling once connection is stable (connected or failed past max retries)
                let currentState = self.connectionState
                if case .connected = currentState { break }
                if case .failed = currentState { break }
                if case .disconnected = currentState { break }
            }
        }
    }

    private func handleDispatcherMessage(_ message: DispatcherMessage) {
        switch message.type {
        case "ack":
            // Server acknowledged receipt of our message
            if let id = message.id {
                messageStatuses[id] = .acknowledged
                messageUpdateTrigger += 1
            }
        case "response":
            handleResponseMessage(message)
        case "status":
            // Status messages update connection info
            if let connected = message.connected {
                isConnected = connected
            }
        case "edit_ack":
            // Server acknowledged edit; the message will be re-dispatched.
            if let id = message.id {
                messageStatuses[id] = .acknowledged
                messageUpdateTrigger += 1
            }
        case "question":
            handleQuestionMessage(message)
        case "notification":
            handleNotificationMessage(message)
        case "error":
            if let id = message.id {
                let errText = message.message ?? "Unknown error"
                messageStatuses[id] = .failed(errText)
            }
            // Only clear global typing if no messages are still processing
            updateGlobalTypingState()
            if let errorText = message.message, let id = message.id {
                let errorMessage = ChatMessage.assistant("Error: \(errorText)", id: "resp-\(id)")
                appendMessage(errorMessage)
            }
        default:
            break
        }
    }

    private func handleResponseMessage(_ message: DispatcherMessage) {
        guard let content = message.content, let id = message.id else { return }

        let isStreaming = message.streaming ?? false

        // The Dispatcher echoes back the same ID we sent with the user message.
        // We must give the assistant message a DIFFERENT ID so that SwiftUI's
        // ForEach (which uses ChatMessage.id as the identity) doesn't confuse
        // the user bubble with the assistant bubble.
        let assistantId = "resp-\(id)"

        // Update per-message status
        messageStatuses[id] = isStreaming ? .processing : .done
        if !isStreaming {
            messageSendTimes.removeValue(forKey: id)
        }

        // Find the original user message to auto-link the reply
        let userMessage = messages.first(where: { $0.id == id && $0.role == .user })
        let replyPreview = userMessage.map { Self.buildReplyPreview(for: $0) }

        if let existingIndex = messages.firstIndex(where: { $0.id == assistantId && $0.role == .assistant }) {
            // Update existing streaming message in place
            messages[existingIndex] = ChatMessage(
                id: assistantId,
                content: content,
                role: .assistant,
                timestamp: messages[existingIndex].timestamp,
                isStreaming: isStreaming,
                replyToId: id,
                replyToPreview: replyPreview
            )
            // Force view update for streaming content changes
            messageUpdateTrigger += 1
        } else {
            // New assistant message — always appended at the end
            let assistantMessage = ChatMessage(
                id: assistantId,
                content: content,
                role: .assistant,
                isStreaming: isStreaming,
                replyToId: id,
                replyToPreview: replyPreview
            )
            messages.append(assistantMessage)
            messageUpdateTrigger += 1
        }

        if !isStreaming {
            currentStreamingMessageId = nil
            saveMessages()
            // Fire a local notification if the app is in background
            // or the user is not on the chat tab.
            sendLocalNotificationIfNeeded(content: content, messageId: assistantId)
        } else {
            currentStreamingMessageId = assistantId
        }

        // Update global typing state based on all pending messages
        updateGlobalTypingState()
    }

    private func handleNotificationMessage(_ message: DispatcherMessage) {
        guard let content = message.content else { return }
        let source = message.source ?? "system"
        let id = message.id ?? UUID().uuidString
        let notifId = "notif-\(id)"
        let notification = ChatMessage.assistant(
            "[\(source)] \(content)",
            id: notifId
        )
        appendMessage(notification)
        messageUpdateTrigger += 1
        // Fire a local push notification for proactive messages
        sendLocalNotificationIfNeeded(content: content, messageId: notifId)
    }

    private func handleQuestionMessage(_ message: DispatcherMessage) {
        guard let questionText = message.question,
              let sessionId = message.sessionId else { return }

        pendingQuestion = questionText
        pendingQuestionOptions = message.options ?? []
        pendingQuestionMessageId = message.id
        pendingQuestionSessionId = sessionId
        pendingQuestionAllowFreeText = message.allowFreeText ?? true

        // Add a system-style message showing the question in the chat
        let optionsText = pendingQuestionOptions.isEmpty
            ? ""
            : "\n\nOptions:\n" + pendingQuestionOptions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let questionMessage = ChatMessage.assistant(
            "Agent asks: \(questionText)\(optionsText)",
            id: "question-\(sessionId)"
        )
        appendMessage(questionMessage)
        messageUpdateTrigger += 1
    }

    /// Send an answer to a pending AskUserQuestion back to the Dispatcher.
    func answerQuestion(_ answer: String) {
        guard let sessionId = pendingQuestionSessionId,
              let messageId = pendingQuestionMessageId else { return }

        let answerText = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answerText.isEmpty else { return }

        // Clear pending question state
        let savedSessionId = sessionId
        let savedMessageId = messageId
        pendingQuestion = nil
        pendingQuestionOptions = []
        pendingQuestionMessageId = nil
        pendingQuestionSessionId = nil
        pendingQuestionAllowFreeText = true

        // Add the user's answer as a chat message
        let answerMessage = ChatMessage.user("Answer: \(answerText)")
        appendMessage(answerMessage)

        // Send the answer to the Dispatcher via WebSocket
        Task {
            do {
                try await webSocket.sendAnswer(
                    id: savedMessageId,
                    sessionId: savedSessionId,
                    answer: answerText
                )
            } catch {
                let errorMessage = ChatMessage.assistant("Failed to send answer: \(error.localizedDescription)")
                self.appendMessage(errorMessage)
            }
        }
    }

    /// Dismiss a pending question without answering.
    func dismissQuestion() {
        pendingQuestion = nil
        pendingQuestionOptions = []
        pendingQuestionMessageId = nil
        pendingQuestionSessionId = nil
        pendingQuestionAllowFreeText = true
    }

    /// Whether any user messages are still waiting for a response to begin.
    /// True when messages are in `.sending` or `.acknowledged` status (server
    /// hasn't started streaming a response yet). Used by the view to show the
    /// typing indicator even while another stream is active.
    var hasMessagesAwaitingResponse: Bool {
        messageStatuses.values.contains { $0 == .sending || $0 == .acknowledged }
    }

    /// Update global isTyping based on whether any messages are still pending.
    private func updateGlobalTypingState() {
        let wasTyping = isTyping
        isTyping = messageStatuses.values.contains(where: {
            $0 == .sending || $0 == .acknowledged || $0 == .processing
        })
        // Manage background task: keep app alive while waiting for responses
        if isTyping && !wasTyping {
            beginBackgroundProcessing()
        } else if !isTyping && wasTyping {
            endBackgroundProcessing()
        }
    }

    /// Request extended background execution time while a response is in flight.
    private func beginBackgroundProcessing() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ChatResponse") { [weak self] in
            // System is about to suspend — clean up
            self?.endBackgroundProcessing()
        }
    }

    /// End the background execution request.
    private func endBackgroundProcessing() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    /// Start a repeating timer that forces a view update every 5 seconds
    /// so progress phase text refreshes as time elapses for pending messages.
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                // Only trigger update if there are pending messages
                if self.messageStatuses.values.contains(where: { $0 == .acknowledged || $0 == .processing }) {
                    self.messageUpdateTrigger += 1
                } else {
                    self.progressTimer?.invalidate()
                    self.progressTimer = nil
                }
            }
        }
    }

    /// Clear all in-flight streaming state. Called on disconnect and reconnect
    /// to prevent the typing indicator from getting permanently stuck.
    private func clearStaleStreamingState() {
        var changed = false
        for (id, status) in messageStatuses {
            if status == .sending || status == .acknowledged || status == .processing {
                messageStatuses[id] = .done
                messageSendTimes.removeValue(forKey: id)
                changed = true
            }
        }

        if currentStreamingMessageId != nil {
            // Mark the streaming message as complete in the messages array
            if let streamingId = currentStreamingMessageId,
               let index = messages.firstIndex(where: { $0.id == streamingId }) {
                messages[index] = ChatMessage(
                    id: messages[index].id,
                    content: messages[index].content,
                    role: .assistant,
                    timestamp: messages[index].timestamp,
                    isStreaming: false,
                    replyToId: messages[index].replyToId,
                    replyToPreview: messages[index].replyToPreview
                )
            }
            currentStreamingMessageId = nil
            changed = true
        }

        if changed {
            updateGlobalTypingState()
            saveMessages()
            messageUpdateTrigger += 1
        }
    }

    /// Build a short preview string for a message being replied to.
    /// Handles text, image, and voice message types appropriately.
    static func buildReplyPreview(for message: ChatMessage) -> String {
        switch message.messageType {
        case .voice:
            // Show [audio] followed by transcribed content if available
            let prefix = "[audio]"
            if !message.content.isEmpty && message.content != "[Voice message]" {
                return "\(prefix) \(message.content)"
            }
            return prefix
        case .image:
            return message.content.isEmpty ? "[Image]" : String(message.content.prefix(80))
        case .text:
            return String(message.content.prefix(80))
        }
    }

    // MARK: - Local Notification Delivery

    /// Send a local push notification for a new assistant message if the user
    /// is not actively viewing the chat tab (app in background, or on another tab).
    private func sendLocalNotificationIfNeeded(content: String, messageId: String) {
        guard let notificationManager else { return }

        let isInBackground = !(appStateRef?.isAppInForeground ?? true)

        if isInBackground {
            // App is in background — send full iOS notification with banner + sound
            let preview = String(content.prefix(200))
            notificationManager.sendFacaiNotification(
                title: "Facai",
                body: preview,
                identifier: messageId
            )
        } else if !isUserOnChatTab {
            // App is in foreground but user is on a different tab —
            // increment the in-app badge count on the chat tab icon.
            notificationManager.unreadChatCount += 1
        }
        // If app is in foreground AND user is on chat tab, do nothing —
        // the message is already visible in the chat view.
    }

    private func saveMessages() {
        ChatMessage.save(messages)
    }
}
