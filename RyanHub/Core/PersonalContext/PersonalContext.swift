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

    /// Build context by injecting ALL provider summaries into every message.
    /// No keyword filtering — the agent always has the full picture and decides
    /// what's relevant. Returns original text unchanged only if every provider
    /// returns nil (no data at all).
    static func buildContext(for userText: String) -> String {
        let sections = providers.compactMap { $0.buildContextSummary() }
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
