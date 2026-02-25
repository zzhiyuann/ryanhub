import Foundation

/// WebSocket client for connecting to the Python Dispatcher.
/// Uses native URLSessionWebSocketTask — no external dependencies.
@Observable
final class WebSocketClient {
    // MARK: - State

    private(set) var isConnected = false
    private(set) var lastError: String?
    private(set) var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(String)
    }

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
    private let baseReconnectDelay: TimeInterval = 2.0
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }

    deinit {
        isIntentionalDisconnect = true
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Public API

    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            lastError = "Invalid WebSocket URL: \(urlString)"
            connectionState = .failed("Invalid URL")
            return
        }
        serverURL = url
        isIntentionalDisconnect = false
        reconnectAttempts = 0
        establishConnection(to: url)
    }

    func disconnect() {
        isIntentionalDisconnect = true
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        updateConnected(false)
        connectionState = .disconnected
    }

    func sendMessage(id: String, content: String, project: String? = nil) async throws {
        let payload = ClientMessage(type: "message", id: id, content: content, project: project)
        let data = try JSONEncoder().encode(payload)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        guard let task = webSocketTask, isConnected else {
            throw WebSocketError.notConnected
        }
        try await task.send(.string(jsonString))
    }

    func testConnection(to urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let testSession = URLSession(configuration: .default)
        let testTask = testSession.webSocketTask(with: url)
        testTask.resume()

        do {
            // Try to receive the initial status message from Dispatcher
            let message = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    let msg = try await testTask.receive()
                    if case .string(let text) = msg,
                       let data = text.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(DispatcherMessage.self, from: data),
                       decoded.type == "status" {
                        return true
                    }
                    return true // Any message means we're connected
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    throw WebSocketError.notConnected
                }
                let result = try await group.next() ?? false
                group.cancelAll()
                return result
            }
            testTask.cancel(with: .goingAway, reason: nil)
            return message
        } catch {
            testTask.cancel(with: .goingAway, reason: nil)
            return false
        }
    }

    // MARK: - Private

    private func establishConnection(to url: URL) {
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        connectionState = reconnectAttempts > 0
            ? .reconnecting(attempt: reconnectAttempts)
            : .connecting

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        // Start receiving immediately — the Dispatcher sends a status message
        // right after connection, which we use to confirm the connection is live.
        startReceiving(expectInitialStatus: true)
        startPing()
    }

    private func startReceiving(expectInitialStatus: Bool = false) {
        receiveTask?.cancel()
        var isFirst = expectInitialStatus

        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let task = self.webSocketTask else { break }
                do {
                    let message = try await task.receive()
                    await MainActor.run {
                        if isFirst {
                            // First message received — connection is confirmed
                            isFirst = false
                            self.lastError = nil
                            self.reconnectAttempts = 0
                            self.updateConnected(true)
                            self.connectionState = .connected
                        }
                        self.handleReceivedMessage(message)
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.handleDisconnection(error: error)
                        }
                    }
                    break
                }
            }
        }

        // Timeout: if no message received within 5 seconds, connection failed
        if expectInitialStatus {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                await MainActor.run {
                    if self.connectionState != .connected && !self.isIntentionalDisconnect {
                        self.handleDisconnection(error: WebSocketError.connectionTimeout)
                    }
                }
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            if let dispatcherMessage = try? JSONDecoder().decode(DispatcherMessage.self, from: data) {
                onMessage?(dispatcherMessage)
            }
        case .data(let data):
            if let dispatcherMessage = try? JSONDecoder().decode(DispatcherMessage.self, from: data) {
                onMessage?(dispatcherMessage)
            }
        @unknown default:
            break
        }
    }

    private func handleDisconnection(error: Error) {
        updateConnected(false)
        lastError = error.localizedDescription
        connectionState = .failed(error.localizedDescription)
        pingTask?.cancel()
        receiveTask?.cancel()

        if !isIntentionalDisconnect {
            attemptReconnect()
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let url = serverURL,
              !isIntentionalDisconnect else {
            if reconnectAttempts >= maxReconnectAttempts {
                connectionState = .failed("Cannot reach Dispatcher")
            }
            return
        }

        reconnectAttempts += 1
        let delay = baseReconnectDelay * pow(2.0, Double(min(reconnectAttempts - 1, 4)))
        connectionState = .reconnecting(attempt: reconnectAttempts)

        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !isIntentionalDisconnect else { return }
            await MainActor.run {
                self.establishConnection(to: url)
            }
        }
    }

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, let task = self.webSocketTask else { break }
                // Send application-level ping (not WebSocket ping frame)
                let pingData = try? JSONEncoder().encode(ClientMessage(type: "ping", id: "", content: "", project: nil))
                if let data = pingData, let str = String(data: data, encoding: .utf8) {
                    try? await task.send(.string(str))
                }
            }
        }
    }

    private func updateConnected(_ value: Bool) {
        isConnected = value
        onConnectionChange?(value)
    }
}

// MARK: - Wire Types

struct ClientMessage: Codable {
    let type: String
    let id: String
    let content: String
    let project: String?
}

struct DispatcherMessage: Codable {
    let type: String        // "response", "status", "error", "pong"
    let id: String?
    let content: String?
    let streaming: Bool?
    let connected: Bool?
    let activeSessions: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case type, id, content, streaming, connected, message
        case activeSessions = "active_sessions"
    }
}

// MARK: - Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case encodingFailed
    case connectionTimeout

    var errorDescription: String? {
        switch self {
        case .notConnected: return "WebSocket is not connected"
        case .encodingFailed: return "Failed to encode message"
        case .connectionTimeout: return "Connection timed out"
        }
    }
}
