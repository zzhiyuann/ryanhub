import Foundation
import SwiftUI
import AVFoundation
import PhotosUI

/// ViewModel for the Chat module. Manages messages, WebSocket communication,
/// image/voice input, chat state, and multi-session management.
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
    /// Maps user message ID → current status.
    var messageStatuses: [String: MessageStatus] = [:]

    /// Status of an individual message in the pipeline.
    enum MessageStatus: Equatable {
        case sending           // Message sent, waiting for ack
        case acknowledged      // Server received (👀)
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

    // MARK: - Session State

    /// The currently active session ID.
    var currentSessionId: String?

    /// All sessions for sidebar display, sorted by lastMessageAt descending.
    var sessions: [ChatSession] = []

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

    /// Maps user message ID → when the message was sent (for progress phases).
    private var messageSendTimes: [String: Date] = [:]

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
        migrateIfNeeded()
        sessions = ChatSession.loadSessions()

        // If there are existing sessions, load the most recent one.
        // Otherwise, create a fresh session.
        if let firstSession = sessions.first {
            currentSessionId = firstSession.id
            messages = ChatMessage.loadSaved(sessionId: firstSession.id)
        } else {
            createNewSession()
        }

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

        // Handle slash commands. Some have local-side effects (e.g. /new creates
        // a local session), but recognized commands are still sent to the Dispatcher
        // as regular messages — the Dispatcher's _classify() parses /commands and
        // @model prefixes from message content. Returns true if fully handled.
        if text.hasPrefix("/") {
            if handleSlashCommand(text) {
                return
            }
        }

        let replyPreview = replyingTo.map { String($0.content.prefix(80)) }
        let userMessage = ChatMessage(
            content: text,
            role: .user,
            replyToId: replyingTo?.id,
            replyToPreview: replyPreview
        )
        appendMessage(userMessage)
        inputText = ""

        // Auto-title: if this is the first user message, set the session title
        autoTitleCurrentSession(from: text)

        let messageId = userMessage.id
        messageStatuses[messageId] = .sending
        messageSendTimes[messageId] = Date()
        isTyping = true
        startProgressTimer()

        // Build the content to send over the wire. If the message is health-related,
        // prepend a structured health data context so the AI can answer questions
        // about weight, food, activity, etc. without backend changes.
        var contentToSend = Self.buildContentWithHealthContext(userText: text)

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
        let replyPreview = replyingTo.map { String($0.content.prefix(80)) }
        let userMessage = ChatMessage(
            content: caption,
            role: .user,
            imageBase64: base64,
            replyToId: replyingTo?.id,
            replyToPreview: replyPreview
        )
        appendMessage(userMessage)

        // Auto-title for image messages
        let titleText = caption.isEmpty ? "[Image]" : caption
        autoTitleCurrentSession(from: titleText)

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
        recordingDuration = 0

        // Auto-title for voice messages
        autoTitleCurrentSession(from: "[Voice message]")

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

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Clear all chat history for the current session.
    func clearHistory() {
        messages.removeAll()
        messageUpdateTrigger += 1

        if let sessionId = currentSessionId {
            ChatMessage.clearSaved(sessionId: sessionId)
            // Update session metadata
            updateCurrentSession(messageCount: 0, lastPreview: "", lastTimestamp: .now)
        }
    }

    // MARK: - Session Management

    /// Create a new chat session and switch to it.
    func createNewSession() {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        currentSessionId = session.id
        messages = []
        messageUpdateTrigger += 1
        isTyping = false
        currentStreamingMessageId = nil
        pruneOldSessions()
        ChatSession.saveSessions(sessions)
    }

    /// Switch to an existing session by ID.
    func switchSession(_ id: String) {
        guard id != currentSessionId else { return }
        guard sessions.contains(where: { $0.id == id }) else { return }

        currentSessionId = id
        messages = ChatMessage.loadSaved(sessionId: id)
        messageUpdateTrigger += 1
        isTyping = false
        currentStreamingMessageId = nil
    }

    /// Delete a session by ID.
    func deleteSession(_ id: String) {
        sessions.removeAll { $0.id == id }
        ChatSession.deleteSession(id: id)

        // If we deleted the current session, switch to the first remaining or create new
        if id == currentSessionId {
            if let firstSession = sessions.first {
                switchSession(firstSession.id)
            } else {
                createNewSession()
            }
        }

        ChatSession.saveSessions(sessions)
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
            contentToSend = Self.buildContentWithHealthContext(userText: message.content)
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

    /// The maximum age (in seconds) within which a sent message can be edited.
    /// Whether a user message can be edited.
    func isMessageEditable(_ message: ChatMessage) -> Bool {
        message.role == .user && message.messageType == .text
    }

    /// Edit a previously sent message: update content, truncate all messages
    /// after it (ChatGPT-style), and re-send to get a fresh response.
    func editMessage(_ message: ChatMessage, newContent: String) {
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isMessageEditable(message) else { return }

        let messageId = message.id

        // Find the edited message and truncate everything after it
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            // Update the message content
            messages[index] = ChatMessage(
                id: messageId,
                content: trimmed,
                role: .user,
                timestamp: message.timestamp,
                replyToId: message.replyToId,
                replyToPreview: message.replyToPreview
            )

            // Remove all messages after this one
            if index + 1 < messages.count {
                messages.removeSubrange((index + 1)...)
            }
            messageUpdateTrigger += 1
        }

        // Reset message status to sending
        messageStatuses[messageId] = .sending
        messageSendTimes[messageId] = Date()
        isTyping = true
        currentStreamingMessageId = nil
        startProgressTimer()

        // Re-send as a regular message (not edit protocol) since we've
        // truncated the conversation — this is effectively a new message.
        var contentToSend = Self.buildContentWithHealthContext(userText: trimmed)
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

        saveMessages()
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

        // /new: create a local session AND tell the Dispatcher to force_new.
        if baseCommand == "/new" {
            let userMessage = ChatMessage.user(text)
            appendMessage(userMessage)
            inputText = ""

            createNewSession()

            // Also send to Dispatcher so it sets force_new for the next task.
            sendCommandAsMessage(text, userMessageId: userMessage.id)

            let systemMsg = ChatMessage.assistant("New session started.")
            appendMessage(systemMsg)
            return true
        }

        // Known server-side commands: send as regular message, Dispatcher handles them.
        if Self.knownCommands.contains(baseCommand) {
            let userMessage = ChatMessage.user(text)
            appendMessage(userMessage)
            inputText = ""
            autoTitleCurrentSession(from: text)

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

    // MARK: - Health Context Injection

    /// If the user's message is health-related, prepend a structured summary of
    /// their recent health data (weight, food, activity) so the AI can answer
    /// questions like "What were my calories today?" without backend changes.
    /// The context is only added to the wire content — the local ChatMessage
    /// stored in the UI always shows the original user text.
    static func buildContentWithHealthContext(userText: String) -> String {
        guard HealthDataProvider.isHealthRelated(userText),
              let context = HealthDataProvider.buildContextSummary() else {
            return userText
        }
        return "\(context)\n\n\(userText)"
    }

    // MARK: - Private

    /// Append a message and notify the view.
    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        messageUpdateTrigger += 1
        saveMessages()
    }

    /// Auto-set the session title from the first user message.
    private func autoTitleCurrentSession(from text: String) {
        guard let sessionId = currentSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        // Only auto-title if the session still has the default title and this is the first message
        let userMessages = messages.filter { $0.role == .user }
        if sessions[index].title == "New Chat" && userMessages.count <= 1 {
            let title = String(text.prefix(50))
            sessions[index].title = title
            ChatSession.saveSessions(sessions)
        }
    }

    /// Update the current session's metadata after a message change.
    private func updateCurrentSession(messageCount: Int, lastPreview: String, lastTimestamp: Date) {
        guard let sessionId = currentSessionId,
              let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].messageCount = messageCount
        sessions[index].lastMessagePreview = lastPreview
        sessions[index].lastMessageAt = lastTimestamp
        // Re-sort sessions so the most recent is first
        sessions.sort { $0.lastMessageAt > $1.lastMessageAt }
        ChatSession.saveSessions(sessions)
    }

    /// Prune sessions beyond the max limit.
    private func pruneOldSessions() {
        let maxSessions = 50
        if sessions.count > maxSessions {
            let removed = sessions.suffix(from: maxSessions)
            for session in removed {
                ChatMessage.clearSaved(sessionId: session.id)
            }
            sessions = Array(sessions.prefix(maxSessions))
        }
    }

    /// Migrate legacy messages (pre-session system) into a new session.
    private func migrateIfNeeded() {
        guard ChatMessage.hasLegacyMessages else { return }

        let legacyMessages = ChatMessage.migrateLegacyMessages()
        guard !legacyMessages.isEmpty else { return }

        // Create a session from the legacy messages
        let firstTimestamp = legacyMessages.first?.timestamp ?? .now
        let lastTimestamp = legacyMessages.last?.timestamp ?? .now
        let firstUserMessage = legacyMessages.first(where: { $0.role == .user })
        let title = firstUserMessage.map { String($0.content.prefix(50)) } ?? "Imported Chat"
        let lastPreview = legacyMessages.last.map { msg -> String in
            let preview = msg.content
            return String(preview.prefix(100))
        } ?? ""

        let session = ChatSession(
            id: UUID().uuidString,
            title: title,
            createdAt: firstTimestamp,
            lastMessageAt: lastTimestamp,
            messageCount: legacyMessages.count,
            lastMessagePreview: lastPreview
        )

        // Save messages under the new session key
        ChatMessage.save(legacyMessages, sessionId: session.id)

        // Save the session
        var existingSessions = ChatSession.loadSessions()
        existingSessions.insert(session, at: 0)
        ChatSession.saveSessions(existingSessions)
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
            // Server acknowledged receipt of our message (👀)
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
            // The ack/response flow will restart automatically via the existing
            // message handling, so just update status to acknowledged.
            if let id = message.id {
                messageStatuses[id] = .acknowledged
                messageUpdateTrigger += 1
            }
        case "question":
            handleQuestionMessage(message)
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
        let replyPreview = userMessage.map { String($0.content.prefix(60)) }

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
        } else {
            currentStreamingMessageId = assistantId
        }

        // Update global typing state based on all pending messages
        updateGlobalTypingState()
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

    /// Update global isTyping based on whether any messages are still pending.
    private func updateGlobalTypingState() {
        isTyping = messageStatuses.values.contains(where: {
            $0 == .sending || $0 == .acknowledged || $0 == .processing
        })
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

    private func saveMessages() {
        ChatMessage.save(messages, sessionId: currentSessionId)

        // Update session metadata
        if let lastMessage = messages.last {
            let preview = String(lastMessage.content.prefix(100))
            updateCurrentSession(
                messageCount: messages.count,
                lastPreview: preview,
                lastTimestamp: lastMessage.timestamp
            )
        }
    }
}
