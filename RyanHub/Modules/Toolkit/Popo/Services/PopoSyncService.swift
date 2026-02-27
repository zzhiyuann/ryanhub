import Foundation

// MARK: - POPO Sync Service

/// Handles syncing sensing events to the bridge server.
/// Posts batches of events to the `/popo/sensing` endpoint with
/// exponential backoff retry on failure.
final class PopoSyncService {
    /// Maximum number of retry attempts for a failed sync.
    private static let maxRetryAttempts = 3

    /// Base delay between retries (doubles each attempt).
    private static let baseRetryDelay: TimeInterval = 5.0

    /// Whether a sync operation is currently in progress.
    private(set) var isSyncing = false

    // MARK: - Bridge Server URL

    /// Base URL for the bridge server, derived from the shared server URL setting.
    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

    // MARK: - Sync

    /// Sync a batch of sensing events to the bridge server.
    /// Returns the IDs of successfully synced events.
    @discardableResult
    func syncEvents(_ events: [SensingEvent]) async -> [UUID] {
        guard !events.isEmpty else { return [] }
        guard !isSyncing else { return [] }

        isSyncing = true
        defer { isSyncing = false }

        let endpoint = "\(Self.bridgeBaseURL)/popo/sensing"
        guard let url = URL(string: endpoint) else {
            print("[PopoSync] Invalid URL: \(endpoint)")
            return []
        }

        // Encode the batch
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(events) else {
            print("[PopoSync] Failed to encode events")
            return []
        }

        // Attempt sync with exponential backoff
        for attempt in 0..<Self.maxRetryAttempts {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
                request.timeoutInterval = 30

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   (200..<300).contains(httpResponse.statusCode) {
                    let syncedIDs = events.map(\.id)
                    print("[PopoSync] Successfully synced \(events.count) events")
                    return syncedIDs
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    print("[PopoSync] Server returned \(statusCode), attempt \(attempt + 1)/\(Self.maxRetryAttempts)")
                }
            } catch {
                print("[PopoSync] Sync failed (attempt \(attempt + 1)/\(Self.maxRetryAttempts)): \(error.localizedDescription)")
            }

            // Exponential backoff before retry
            if attempt < Self.maxRetryAttempts - 1 {
                let delay = Self.baseRetryDelay * pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        print("[PopoSync] All retry attempts exhausted for \(events.count) events")
        return []
    }
}
