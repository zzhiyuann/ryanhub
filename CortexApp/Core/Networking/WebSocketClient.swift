import Foundation

/// WebSocket client for connecting to the Python Dispatcher.
/// Uses native URLSessionWebSocketTask — no external dependencies.
@Observable
final class WebSocketClient {
    // MARK: - State

    private(set) var isConnected = false
    private(set) var lastError: String?

    // MARK: - Callbacks

    var onMessage: ((DispatcherMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    // MARK: - Private

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var serverURL: URL?
    private var isIntentionalDisconnect = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 1.0

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Connect to the Dispatcher WebSocket server.
    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            lastError = "Invalid WebSocket URL: \(urlString)"
            return
        }
        serverURL = url
        isIntentionalDisconnect = false
        reconnectAttempts = 0
        establishConnection(to: url)
    }

    /// Disconnect from the server.
    func disconnect() {
        isIntentionalDisconnect = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        onConnectionChange?(false)
    }

    /// Send a chat message to the Dispatcher.
    func sendMessage(id: String, content: String, project: String? = nil) async throws {
        let payload = ClientMessage(type: "message", id: id, content: content, project: project)
        let data = try JSONEncoder().encode(payload)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        guard let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        try await task.send(.string(jsonString))
    }

    /// Test connectivity by attempting a connection and immediately disconnecting.
    func testConnection(to urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let testTask = session.webSocketTask(with: url)
        testTask.resume()

        // Wait briefly for connection
        try? await Task.sleep(for: .seconds(2))
        let connected = testTask.closeCode == .invalid // still open means connected
        testTask.cancel(with: .goingAway, reason: nil)
        return connected
    }

    // MARK: - Private

    private func establishConnection(to url: URL) {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        isConnected = true
        lastError = nil
        reconnectAttempts = 0
        onConnectionChange?(true)

        startReceiving()
        startPing()
    }

    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleReceivedMessage(message)
                self.startReceiving() // Continue listening
            case .failure(let error):
                self.handleDisconnection(error: error)
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            if let dispatcherMessage = try? JSONDecoder().decode(DispatcherMessage.self, from: data) {
                Task { @MainActor in
                    self.onMessage?(dispatcherMessage)
                }
            }
        case .data(let data):
            if let dispatcherMessage = try? JSONDecoder().decode(DispatcherMessage.self, from: data) {
                Task { @MainActor in
                    self.onMessage?(dispatcherMessage)
                }
            }
        @unknown default:
            break
        }
    }

    private func handleDisconnection(error: Error) {
        Task { @MainActor in
            self.isConnected = false
            self.lastError = error.localizedDescription
            self.onConnectionChange?(false)

            if !self.isIntentionalDisconnect {
                self.attemptReconnect()
            }
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let url = serverURL else { return }

        reconnectAttempts += 1
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))

        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !isIntentionalDisconnect else { return }
            establishConnection(to: url)
        }
    }

    private func startPing() {
        Task {
            while !isIntentionalDisconnect, webSocketTask != nil {
                try? await Task.sleep(for: .seconds(30))
                webSocketTask?.sendPing { [weak self] error in
                    if let error {
                        self?.handleDisconnection(error: error)
                    }
                }
            }
        }
    }
}

// MARK: - Wire Types

/// Message sent from client to Dispatcher.
struct ClientMessage: Codable {
    let type: String
    let id: String
    let content: String
    let project: String?
}

/// Message received from Dispatcher.
struct DispatcherMessage: Codable {
    let type: String        // "response", "status", "error"
    let id: String?
    let content: String?
    let streaming: Bool?
    let connected: Bool?
    let activeSessions: Int?
    let message: String?    // error message

    enum CodingKeys: String, CodingKey {
        case type, id, content, streaming, connected, message
        case activeSessions = "active_sessions"
    }
}

// MARK: - Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: return "WebSocket is not connected"
        case .encodingFailed: return "Failed to encode message"
        }
    }
}
