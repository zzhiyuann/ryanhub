import Foundation

// MARK: - Toolkit Data Provider Protocol

/// Protocol for toolkit modules to expose personal data as chat context.
/// Each conforming type provides keyword-based relevance detection and a formatted
/// summary that gets injected into the chat message when the user asks a related question.
///
/// To add a new toolkit:
/// 1. Create `XxxDataProvider` conforming to `ToolkitDataProvider`
/// 2. Add `XxxDataProvider.self` to `PersonalContext.providers`
protocol ToolkitDataProvider {
    /// Unique identifier for this toolkit (e.g., "health", "parking").
    static var toolkitId: String { get }

    /// Human-readable name shown in context tags (e.g., "Health Data").
    static var displayName: String { get }

    /// Keywords that trigger this provider. Matched case-insensitively against user input.
    static var relevanceKeywords: [String] { get }

    /// Check whether a user message is relevant to this toolkit.
    /// Default implementation performs case-insensitive keyword matching.
    static func isRelevant(to text: String) -> Bool

    /// Build a formatted context summary for injection into the chat message.
    /// Returns `nil` if there is no data available.
    static func buildContextSummary() -> String?
}

// MARK: - Default Implementation

extension ToolkitDataProvider {
    static func isRelevant(to text: String) -> Bool {
        let lowered = text.lowercased()
        return relevanceKeywords.contains { lowered.contains($0) }
    }
}
