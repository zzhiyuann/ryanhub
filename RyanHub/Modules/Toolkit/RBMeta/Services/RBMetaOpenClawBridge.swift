import Foundation

enum RBOpenClawConnectionState: Equatable {
    case notConfigured
    case checking
    case connected
    case unreachable(String)
}

@MainActor
class RBOpenClawBridge {
    var lastToolCallStatus: RBToolCallStatus = .idle
    var connectionState: RBOpenClawConnectionState = .notConfigured

    private let session: URLSession
    private let pingSession: URLSession
    private var sessionKey: String
    private var conversationHistory: [[String: String]] = []
    private let maxHistoryTurns = 10

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)

        let pingConfig = URLSessionConfiguration.default
        pingConfig.timeoutIntervalForRequest = 5
        self.pingSession = URLSession(configuration: pingConfig)

        self.sessionKey = RBOpenClawBridge.newSessionKey()
    }

    func checkConnection() async {
        guard RBMetaConfig.isOpenClawConfigured else {
            connectionState = .notConfigured
            return
        }
        connectionState = .checking
        guard let url = URL(string: "\(RBMetaConfig.openClawHost):\(RBMetaConfig.openClawPort)/v1/chat/completions") else {
            connectionState = .unreachable("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(RBMetaConfig.openClawGatewayToken)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await pingSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                connectionState = .connected
            } else {
                connectionState = .unreachable("Unexpected response")
            }
        } catch {
            connectionState = .unreachable(error.localizedDescription)
        }
    }

    func resetSession() {
        sessionKey = RBOpenClawBridge.newSessionKey()
        conversationHistory = []
    }

    private static func newSessionKey() -> String {
        let ts = ISO8601DateFormatter().string(from: Date())
        return "agent:main:rbmeta:\(ts)"
    }

    func delegateTask(
        task: String,
        toolName: String = "execute"
    ) async -> RBToolResult {
        lastToolCallStatus = .executing(toolName)

        guard let url = URL(string: "\(RBMetaConfig.openClawHost):\(RBMetaConfig.openClawPort)/v1/chat/completions") else {
            lastToolCallStatus = .failed(toolName, "Invalid URL")
            return .failure("Invalid gateway URL")
        }

        conversationHistory.append(["role": "user", "content": task])

        if conversationHistory.count > maxHistoryTurns * 2 {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryTurns * 2))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(RBMetaConfig.openClawGatewayToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionKey, forHTTPHeaderField: "x-openclaw-session-key")

        let body: [String: Any] = [
            "model": "openclaw",
            "messages": conversationHistory,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            guard let statusCode = httpResponse?.statusCode, (200...299).contains(statusCode) else {
                let code = httpResponse?.statusCode ?? 0
                lastToolCallStatus = .failed(toolName, "HTTP \(code)")
                return .failure("Agent returned HTTP \(code)")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                conversationHistory.append(["role": "assistant", "content": content])
                lastToolCallStatus = .completed(toolName)
                return .success(content)
            }

            let raw = String(data: data, encoding: .utf8) ?? "OK"
            conversationHistory.append(["role": "assistant", "content": raw])
            lastToolCallStatus = .completed(toolName)
            return .success(raw)
        } catch {
            lastToolCallStatus = .failed(toolName, error.localizedDescription)
            return .failure("Agent error: \(error.localizedDescription)")
        }
    }
}
