import Foundation
import SwiftUI

// MARK: - Dashboard View Model

@Observable
@MainActor
final class DashboardViewModel {
    var mainlines: [DashboardMainline] = []
    var today: DashboardToday?
    var agentEvents: [DashboardAgentEvent] = []
    var agents: [String: DashboardAgent] = [:]
    var isLoading = false
    var errorMessage: String?
    var lastRefresh: Date?

    /// New task name being entered per mainline (keyed by mainline id).
    var newTaskText: [String: String] = [:]

    /// New standalone today item text.
    var newTodayItemText = ""

    private var refreshTimer: Timer?

    // MARK: - Base URL

    /// Dashboard server URL via Tailscale.
    private var baseURL: String {
        return "https://zhiyuans-imac.tail88572f.ts.net/dashboard"
    }

    // MARK: - Computed Properties

    var sortedMainlines: [DashboardMainline] {
        mainlines.sorted { a, b in
            if a.priorityColor.sortOrder != b.priorityColor.sortOrder {
                return a.priorityColor.sortOrder < b.priorityColor.sortOrder
            }
            // Then by deadline (soonest first, nil last)
            switch (a.daysUntilDeadline, b.daysUntilDeadline) {
            case let (.some(da), .some(db)): return da < db
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a.name < b.name
            }
        }
    }

    var criticalMainlines: [DashboardMainline] {
        sortedMainlines.filter { $0.priority == "critical" }
    }

    var todayItems: [DashboardTodayItem] {
        today?.items ?? []
    }

    var todayCompletedCount: Int {
        todayItems.filter(\.done).count
    }

    var todayTotalCount: Int {
        todayItems.count
    }

    var todayProgress: Double {
        guard todayTotalCount > 0 else { return 0 }
        return Double(todayCompletedCount) / Double(todayTotalCount)
    }

    // MARK: - Lifecycle

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadData()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - API: Load Data

    func loadData() async {
        isLoading = mainlines.isEmpty
        errorMessage = nil

        do {
            let url = URL(string: "\(baseURL)/api/mainlines")!
            let session = Self.makeSession()
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DashboardError.serverError
            }

            let decoded = try JSONDecoder().decode(DashboardResponse.self, from: data)
            mainlines = decoded.mainlines
            today = decoded.today
            agentEvents = decoded.agentEvents ?? []
            agents = decoded.agents ?? [:]
            lastRefresh = Date()

            // Cache for data provider
            UserDefaults.standard.set(data, forKey: "dashboard_cache")
        } catch {
            if mainlines.isEmpty {
                errorMessage = error.localizedDescription
            }
            // Keep stale data if we had some
        }

        isLoading = false
    }

    // MARK: - API: Today Items

    func toggleTodayItem(_ item: DashboardTodayItem) async {
        do {
            let url = URL(string: "\(baseURL)/api/today/\(item.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["done": !item.done]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let session = Self.makeSession()
            _ = try await session.data(for: request)

            // Optimistic update
            if let idx = today?.items.firstIndex(where: { $0.id == item.id }) {
                today?.items[idx].done = !item.done
            }
        } catch {
            errorMessage = "Failed to update item"
        }
    }

    func addTodayItem() async {
        let text = newTodayItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            let url = URL(string: "\(baseURL)/api/today")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = ["type": "standalone", "name": text]
            request.httpBody = try JSONEncoder().encode(body)
            let session = Self.makeSession()
            _ = try await session.data(for: request)
            newTodayItemText = ""
            await loadData()
        } catch {
            errorMessage = "Failed to add item"
        }
    }

    func deleteTodayItem(_ item: DashboardTodayItem) async {
        do {
            let url = URL(string: "\(baseURL)/api/today/\(item.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let session = Self.makeSession()
            _ = try await session.data(for: request)

            // Optimistic removal
            today?.items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Failed to delete item"
        }
    }

    // MARK: - API: Tasks

    func addTask(to mainlineId: String) async {
        let text = (newTaskText[mainlineId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            let url = URL(string: "\(baseURL)/api/mainlines/\(mainlineId)/tasks")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = ["name": text]
            request.httpBody = try JSONEncoder().encode(body)
            let session = Self.makeSession()
            _ = try await session.data(for: request)
            newTaskText[mainlineId] = ""
            await loadData()
        } catch {
            errorMessage = "Failed to add task"
        }
    }

    func updateTaskStatus(mainlineId: String, taskId: String, status: String) async {
        do {
            let url = URL(string: "\(baseURL)/api/mainlines/\(mainlineId)/tasks/\(taskId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = ["status": status]
            request.httpBody = try JSONEncoder().encode(body)
            let session = Self.makeSession()
            _ = try await session.data(for: request)

            // Optimistic update
            if let mi = mainlines.firstIndex(where: { $0.id == mainlineId }),
               let ti = mainlines[mi].tasks.firstIndex(where: { $0.id == taskId }) {
                mainlines[mi].tasks[ti].status = status
            }
        } catch {
            errorMessage = "Failed to update task"
        }
    }

    func deleteTask(mainlineId: String, taskId: String) async {
        do {
            let url = URL(string: "\(baseURL)/api/mainlines/\(mainlineId)/tasks/\(taskId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let session = Self.makeSession()
            _ = try await session.data(for: request)

            // Optimistic removal
            if let mi = mainlines.firstIndex(where: { $0.id == mainlineId }) {
                mainlines[mi].tasks.removeAll { $0.id == taskId }
            }
        } catch {
            errorMessage = "Failed to delete task"
        }
    }

    // MARK: - URLSession (trust self-signed certs for Tailscale)

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config, delegate: DashboardTrustDelegate.shared, delegateQueue: nil)
    }
}

// MARK: - Errors

enum DashboardError: LocalizedError {
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .serverError: return "Dashboard server is unreachable"
        case .decodingError: return "Failed to parse dashboard data"
        }
    }
}

// MARK: - SSL Trust Delegate

/// Trusts all certificates for dashboard connections (Tailscale).
final class DashboardTrustDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = DashboardTrustDelegate()

    private func handleChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // Session-level
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }

    // Task-level
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }
}
