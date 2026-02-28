import Foundation

// MARK: - Nudge Type

/// The category of a proactive nudge delivered to the user.
enum NudgeType: String, Codable, CaseIterable {
    case insight         // Data-driven observation
    case reminder        // Time-based or context-based reminder
    case encouragement   // Positive reinforcement
    case alert           // Urgent or important notification
}

// MARK: - Nudge

/// A proactive nudge generated from sensing data analysis.
/// Nudges are contextual suggestions, insights, or reminders
/// triggered by behavioral patterns.
struct Nudge: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let content: String
    let trigger: String
    let type: NudgeType
    let priority: String
    let relatedModalities: [String]?
    var acknowledged: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        content: String,
        trigger: String,
        type: NudgeType,
        priority: String = "normal",
        relatedModalities: [String]? = nil,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.trigger = trigger
        self.type = type
        self.priority = priority
        self.relatedModalities = relatedModalities
        self.acknowledged = acknowledged
    }
}
