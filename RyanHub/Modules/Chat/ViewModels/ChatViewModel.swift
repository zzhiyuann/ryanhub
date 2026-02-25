import Foundation
import SwiftUI

/// ViewModel for the Chat module. Manages messages, WebSocket communication,
/// and chat state.
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isTyping: Bool = false
    var isConnected: Bool = false
    var connectionState: WebSocketClient.ConnectionState = .disconnected
    var connectionError: String?

    // MARK: - Private

    private let webSocket = WebSocketClient()
    private var currentStreamingMessageId: String?
    private var serverURL: String?

    // MARK: - Init

    init() {
        messages = ChatMessage.loadSaved()
        setupWebSocketCallbacks()
    }

    // MARK: - Public API

    /// Connect to the Dispatcher WebSocket.
    func connect(to url: String) {
        serverURL = url
        webSocket.connect(to: url)
    }

    /// Disconnect from the Dispatcher.
    func disconnect() {
        webSocket.disconnect()
    }

    /// Retry connection to the Dispatcher.
    func retry() {
        guard let url = serverURL else { return }
        webSocket.connect(to: url)
    }

    /// Send the current input text as a message.
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage.user(text)
        messages.append(userMessage)
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
                    self.messages.append(errorMessage)
                    self.saveMessages()
                }
            }
        }
    }

    /// Clear all chat history.
    func clearHistory() {
        messages.removeAll()
        ChatMessage.clearSaved()
    }

    // MARK: - Private

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
            }
        }

        webSocket.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleDispatcherMessage(message)
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
                messages.append(errorMessage)
                saveMessages()
            }
        default:
            break
        }
    }

    private func handleResponseMessage(_ message: DispatcherMessage) {
        guard let content = message.content, let id = message.id else { return }

        let isStreaming = message.streaming ?? false

        if let existingIndex = messages.firstIndex(where: { $0.id == id && $0.role == .assistant }) {
            // Update existing streaming message
            messages[existingIndex] = ChatMessage(
                id: id,
                content: content,
                role: .assistant,
                timestamp: messages[existingIndex].timestamp,
                isStreaming: isStreaming
            )
        } else {
            // New assistant message
            let assistantMessage = ChatMessage.assistant(content, id: id, isStreaming: isStreaming)
            messages.append(assistantMessage)
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
