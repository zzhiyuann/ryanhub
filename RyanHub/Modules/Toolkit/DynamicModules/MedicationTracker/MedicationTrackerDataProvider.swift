import Foundation

// MARK: - MedicationTracker Data Provider

/// Provides medication tracker data for chat context injection.
/// Reads from bridge server at /modules/medicationTracker/data.
enum MedicationTrackerDataProvider: ToolkitDataProvider {

    static let toolkitId = "medicationTracker"
    static let displayName = "Medication Tracker"

    static let relevanceKeywords: [String] = [
        "medication", "medicine", "pills", "dose", "schedule", "reminder", "drug", "prescription", "药物", "用药", "剂量", "服药", "处方"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_medicationTracker_cache"),
              let entries = try? JSONDecoder().decode([MedicationTrackerEntry].self, from: data),
              !entries.isEmpty else {
            return nil
        }

        var lines: [String] = ["[\(displayName)]"]
        lines.append("Total entries: \(entries.count)")

        // Show last 5 entries
        let recent = entries.suffix(5)
        for entry in recent {
            lines.append("  - \(entry.summaryLine)")
        }

        // Action hints for the AI agent
        lines.append("Actions:")
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/medicationTracker/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/medicationTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
