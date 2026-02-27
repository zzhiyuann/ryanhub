import Foundation

// MARK: - Personal Context

/// Unified personal knowledge bus. Queries all registered toolkit data providers
/// and assembles relevant context for injection into chat messages.
///
/// Adding a new toolkit requires just two steps:
/// 1. Create a type conforming to `ToolkitDataProvider`
/// 2. Add it to the `providers` array below
enum PersonalContext {

    /// The ONE registry of all toolkit data providers.
    static let providers: [any ToolkitDataProvider.Type] = [
        HealthDataProvider.self,
        FluentDataProvider.self,
        ParkingDataProvider.self,
        CalendarDataProvider.self,
        BookFactoryDataProvider.self,
    ]

    /// Build context for a specific user message by filtering relevant providers.
    /// Returns the original text unchanged if no providers match.
    static func buildContext(for userText: String) -> String {
        let relevant = providers.filter { $0.isRelevant(to: userText) }
        guard !relevant.isEmpty else { return userText }

        let sections = relevant.compactMap { $0.buildContextSummary() }
        guard !sections.isEmpty else { return userText }

        var parts = ["[Personal Context]"]
        parts.append(contentsOf: sections)
        parts.append("[End Personal Context]")

        return parts.joined(separator: "\n") + "\n\n" + userText
    }

    /// Build a full snapshot from ALL providers (for daily briefing / debug).
    static func buildFullSnapshot() -> String? {
        let sections = providers.compactMap { $0.buildContextSummary() }
        guard !sections.isEmpty else { return nil }

        var parts = ["[Personal Context — Full Snapshot]"]
        parts.append(contentsOf: sections)
        parts.append("[End Personal Context]")

        return parts.joined(separator: "\n")
    }
}
