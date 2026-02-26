import Foundation

/// ViewModel for the Settings module.
@MainActor @Observable
final class SettingsViewModel {
    // MARK: - State

    var isTesting: Bool = false
    var testResultIcon: String?
    var serverURLWarning: String?
    // MARK: - Computed

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Public API

    func loadFromAppState(_ appState: AppState) {
        validateServerURL(appState.serverURL)
    }

    /// Validate WebSocket URL format and update warning message.
    func validateServerURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            serverURLWarning = nil
            return
        }
        if !trimmed.hasPrefix("ws://") && !trimmed.hasPrefix("wss://") {
            serverURLWarning = "URL must start with ws:// or wss://"
        } else if URL(string: trimmed) == nil {
            serverURLWarning = "Invalid URL format"
        } else {
            serverURLWarning = nil
        }
    }

    /// Test WebSocket connection to the given URL.
    func testConnection(url: String) {
        guard !isTesting else { return }
        isTesting = true
        testResultIcon = nil

        let client = WebSocketClient()
        Task {
            let success = await client.testConnection(to: url)
            self.isTesting = false
            self.testResultIcon = success ? "checkmark.circle.fill" : "xmark.circle.fill"

            // Reset icon after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                self.testResultIcon = nil
            }
        }
    }
}
