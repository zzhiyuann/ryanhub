import Foundation
import SwiftUI

// MARK: - ScreenTimeGoal View Model

@Observable
@MainActor
final class ScreenTimeGoalViewModel {
    var entries: [ScreenTimeGoalEntry] = []
    var isLoading = false
    var errorMessage: String?

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() {
        Task { await loadData() }
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let url = URL(string: "\(bridgeBaseURL)/modules/screenTimeGoal/data")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            entries = try decoder.decode([ScreenTimeGoalEntry].self, from: data)
            // Cache for DataProvider context injection
            UserDefaults.standard.set(data, forKey: "dynamic_module_screenTimeGoal_cache")
        } catch {
            entries = []
        }
    }

    func addEntry(_ entry: ScreenTimeGoalEntry) async {
        do {
            let url = URL(string: "\(bridgeBaseURL)/modules/screenTimeGoal/data/add")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            let _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = "Failed to add entry"
        }
    }

    func deleteEntry(_ entry: ScreenTimeGoalEntry) async {
        do {
            let url = URL(string: "\(bridgeBaseURL)/modules/screenTimeGoal/data?id=\(entry.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = "Failed to delete entry"
        }
    }
}
