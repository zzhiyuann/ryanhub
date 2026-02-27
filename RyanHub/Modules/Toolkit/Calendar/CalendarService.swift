import Foundation

// MARK: - Calendar Service

/// Network service for communicating with the calendar sync server.
/// Pattern follows FoodAnalysisService.
@MainActor
final class CalendarService {

    var bridgeBaseURL: String

    nonisolated init(bridgeBaseURL: String = "http://localhost:18791") {
        self.bridgeBaseURL = bridgeBaseURL
    }

    // MARK: - Public API

    /// Fetch all available calendars.
    func fetchCalendars() async throws -> [CalendarInfo] {
        let url = try buildURL(path: "/calendars")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([CalendarInfo].self, from: data)
    }

    /// Fetch events across all calendars within a time range.
    func fetchEvents(start: Date, end: Date) async throws -> [CalendarEvent] {
        var components = URLComponents(string: bridgeBaseURL + "/events")!
        components.queryItems = [
            URLQueryItem(name: "start", value: iso8601Formatter.string(from: start)),
            URLQueryItem(name: "end", value: iso8601Formatter.string(from: end)),
        ]
        guard let url = components.url else {
            throw CalendarServiceError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([CalendarEvent].self, from: data)
    }

    /// Create an event via structured JSON.
    func createEvent(
        title: String,
        startTime: Date,
        endTime: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarId: String = "primary"
    ) async throws -> [String: Any] {
        let url = try buildURL(path: "/events")
        var body: [String: Any] = [
            "title": title,
            "startTime": iso8601Formatter.string(from: startTime),
            "endTime": iso8601Formatter.string(from: endTime),
            "calendarId": calendarId,
        ]
        if let location { body["location"] = location }
        if let notes { body["notes"] = notes }

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// Delete an event.
    func deleteEvent(eventId: String, calendarId: String = "primary") async throws {
        let encodedId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        var components = URLComponents(string: bridgeBaseURL + "/events/" + encodedId)!
        components.queryItems = [
            URLQueryItem(name: "calendar_id", value: calendarId),
        ]
        guard let url = components.url else {
            throw CalendarServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw CalendarServiceError.serverError(httpResponse.statusCode)
        }
    }

    /// Process a natural language command via the AI agent.
    func processNaturalLanguage(_ text: String) async throws -> AgentCalendarResponse {
        let url = try buildURL(path: "/agent")
        let body = ["text": text]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90  // Agent calls Claude CLI, can be slow

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorBody?["error"] as? String ?? "Server error"
            return AgentCalendarResponse(message: message, action: "error", eventId: nil)
        }
        return try decoder.decode(AgentCalendarResponse.self, from: data)
    }

    /// Check if the server is reachable.
    func healthCheck() async -> Bool {
        guard let url = try? buildURL(path: "/health") else { return false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONSerialization.jsonObject(with: data) as? [String: String]
            return result?["status"] == "ok"
        } catch {
            return false
        }
    }

    // MARK: - Private

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Try date-only format (all-day events: "2026-02-27")
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.timeZone = TimeZone(identifier: "America/New_York")
            if let date = dateOnly.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return d
    }()

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: bridgeBaseURL + path) else {
            throw CalendarServiceError.invalidURL
        }
        return url
    }
}

// MARK: - Errors

enum CalendarServiceError: LocalizedError {
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid calendar server URL"
        case .serverError(let code): return "Server error (HTTP \(code))"
        }
    }
}
