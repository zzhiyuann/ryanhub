import Foundation

/// ViewModel for the Settings module.
@Observable
final class SettingsViewModel {
    // MARK: - State

    var isTesting: Bool = false
    var testResultIcon: String?

    // MARK: - Computed

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Public API

    func loadFromAppState(_ appState: AppState) {
        // Sync any initial state if needed
    }

    /// Test WebSocket connection to the given URL.
    func testConnection(url: String) {
        guard !isTesting else { return }
        isTesting = true
        testResultIcon = nil

        let client = WebSocketClient()
        Task {
            let success = await client.testConnection(to: url)
            await MainActor.run {
                self.isTesting = false
                self.testResultIcon = success ? "checkmark.circle.fill" : "xmark.circle.fill"

                // Reset icon after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        self.testResultIcon = nil
                    }
                }
            }
        }
    }
}
