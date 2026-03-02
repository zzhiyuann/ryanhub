import Foundation

// MARK: - BoBo Data Provider

/// Provides BoBo API access instructions for chat context injection.
/// Tells the agent how to read the processed timeline (same as what the phone UI displays)
/// and how to write diary entries via the bridge server.
enum BoboDataProvider: ToolkitDataProvider {

    static let toolkitId = "bobo"
    static let displayName = "BoBo Behavioral Sensing"

    static let relevanceKeywords: [String] = [
        "bobo", "timeline", "sensing", "narration", "behavior", "movement",
        "activity", "motion", "walking", "driving", "stationary", "sleep",
        "heart rate", "steps", "screen time", "location", "mood", "emotion",
        "diary", "journal", "today", "yesterday", "schedule", "routine",
        // Chinese
        "行为", "活动", "运动", "走路", "开车", "心率", "步数",
        "日记", "情绪", "心情", "时间线", "作息"
    ]

    static func buildContextSummary() -> String? {
        var lines: [String] = ["[\(displayName)]"]

        lines.append("BoBo is the user's behavioral sensing system that tracks motion, steps, heart rate, HRV, sleep, location, screen usage, workouts, and more. It also stores voice/text diary narrations with emotion analysis.")
        lines.append("")
        lines.append("READ — Get the user's processed timeline (filtered, deduplicated, same as what the phone UI shows):")
        lines.append("curl -s http://localhost:18790/bobo/timeline")
        lines.append("Returns JSON: {date, totalEvents, summary: {steps, narrations, nudges, screenEvents, locationChanges, caloriesConsumed, caloriesBurned, activityMinutes, activityBreakdown}, items: [{time, type, detail}, ...]}.")
        lines.append("Items are sorted newest-first. Each item has: time (e.g. '12:08 PM'), type (e.g. 'Motion', 'Heart Rate', 'Location'), detail (e.g. 'Walking (8s) → Stationary', '91 BPM', 'University of Virginia').")
        lines.append("This is the ONLY endpoint to use for timeline analysis — it contains all processed data from the phone.")
        lines.append("")
        lines.append("WRITE — Add a diary entry to BoBo timeline:")
        lines.append("curl -s -X POST http://localhost:18790/bobo/narrations/add -H 'Content-Type: application/json' -d '{\"transcript\":\"what the user said or described\"}'")
        lines.append("Use this when the user wants to log something to their timeline. Keep transcript concise and factual.")

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
