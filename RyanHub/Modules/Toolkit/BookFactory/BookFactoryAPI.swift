import Foundation
import os

private let logger = Logger(subsystem: "com.ryanhub.app", category: "BookFactoryAPI")

// MARK: - API Error

enum BookFactoryAPIError: LocalizedError {
    case noServerURL
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noServerURL:
            return "Book Factory server URL not configured"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .decodingError(let err):
            return "Data error: \(err.localizedDescription)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - API Client

@Observable
final class BookFactoryAPI: @unchecked Sendable {
    /// The base URL for the Book Factory server (e.g. "https://192.168.1.100:3443")
    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "bookfactory_server_url")
        }
    }

    /// Optional auth token — passed as query parameter for audio chunks, as Bearer header otherwise
    var authToken: String? {
        didSet {
            UserDefaults.standard.set(authToken, forKey: "bookfactory_auth_token")
        }
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: String? = nil, authToken: String? = nil) {
        let storedURL = UserDefaults.standard.string(forKey: "bookfactory_server_url") ?? ""
        self.baseURL = baseURL ?? storedURL

        let storedToken = UserDefaults.standard.string(forKey: "bookfactory_auth_token")
        self.authToken = authToken ?? storedToken

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        // Allow connecting to local HTTPS servers with self-signed certs
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Request Building

    private func makeRequest(_ path: String, method: String = "GET", body: (any Encodable)? = nil) throws -> URLRequest {
        guard !baseURL.isEmpty else { throw BookFactoryAPIError.noServerURL }
        guard let url = URL(string: "\(baseURL)\(path)") else { throw BookFactoryAPIError.noServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    // MARK: - Generic Requests

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path)
        return try await execute(request)
    }

    func post<T: Decodable>(_ path: String, body: (any Encodable)? = nil) async throws -> T {
        let request = try makeRequest(path, method: "POST", body: body)
        return try await execute(request)
    }

    func put<T: Decodable>(_ path: String, body: (any Encodable)? = nil) async throws -> T {
        let request = try makeRequest(path, method: "PUT", body: body)
        return try await execute(request)
    }

    func delete(_ path: String) async throws {
        let request = try makeRequest(path, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode >= 400 {
            let msg = (try? decoder.decode([String: String].self, from: data))?["error"] ?? "Unknown"
            throw BookFactoryAPIError.serverError(http.statusCode, msg)
        }
    }

    func getString(_ path: String) async throws -> String {
        let request = try makeRequest(path)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BookFactoryAPIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode >= 400 {
            throw BookFactoryAPIError.serverError(http.statusCode, "Failed to fetch content")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Audio Chunk URL

    /// Build a URL for streaming an audio chunk, with auth token as query parameter
    func chunkURL(bookId: String, index: Int) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        var comps = URLComponents(string: "\(baseURL)/api/audiobook/\(bookId)/chunk/\(index)")
        if let token = authToken {
            comps?.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        return comps?.url
    }

    // MARK: - Convenience: Login

    func login(username: String, password: String) async throws -> LoginResponse {
        struct LoginBody: Encodable { let username: String; let password: String }
        let request = try makeRequest(
            "/api/auth/login",
            method: "POST",
            body: LoginBody(username: username, password: password)
        )
        let response: LoginResponse = try await execute(request)
        authToken = response.token
        return response
    }

    // MARK: - Server URL Management

    func saveServerURL(_ url: String) {
        var cleaned = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.hasPrefix("http://") && !cleaned.hasPrefix("https://") {
            cleaned = "https://\(cleaned)"
        }
        if cleaned.hasSuffix("/") { cleaned = String(cleaned.dropLast()) }
        baseURL = cleaned
    }

    // MARK: - Private

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        logger.info("Request: \(request.httpMethod ?? "?", privacy: .public) \(request.url?.absoluteString ?? "nil", privacy: .public)")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            throw BookFactoryAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BookFactoryAPIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode >= 400 {
            let msg = (try? decoder.decode([String: String].self, from: data))?["error"] ?? "Unknown error"
            throw BookFactoryAPIError.serverError(http.statusCode, msg)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BookFactoryAPIError.decodingError(error)
        }
    }
}

// MARK: - Auth Models (used only for login flow)

struct LoginResponse: Codable {
    let token: String
    let user: LoginUser
}

struct LoginUser: Codable {
    let id: String
    let username: String
    let displayName: String
    let hasOpenaiKey: Bool?
    let hasAnthropicKey: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case hasOpenaiKey = "has_openai_key"
        case hasAnthropicKey = "has_anthropic_key"
    }
}
