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
        lines.append("READ — Query a specific local calendar day (use this for today/yesterday/any explicit date):")
        lines.append("curl -s 'http://localhost:18790/bobo/day?date=YYYY-MM-DD'")
        lines.append("This endpoint also accepts date=today and date=yesterday.")
        lines.append("For any other day, resolve the requested local date explicitly and query that date.")
        lines.append("Returns JSON: {date, timezone, isToday, counts, summary, items}.")
        lines.append("items are sorted newest-first and include sensing, narrations, nudges, meals, activities, and weight entries with UTC timestamp + localTime.")
        lines.append("This is the PRIMARY endpoint for any date-aware timeline/sleep/routine question.")
        lines.append("")
        lines.append("READ — Query multiple local calendar days for trends, mood, routine, or mental-state questions:")
        lines.append("curl -s 'http://localhost:18790/bobo/range?days=7'")
        lines.append("Or: curl -s 'http://localhost:18790/bobo/range?start=YYYY-MM-DD&end=YYYY-MM-DD'")
        lines.append("Use this first when the user asks about patterns over days, the past week, or changes over time.")
        lines.append("Returns JSON: {startDate, endDate, timezone, dayCount, totals, days}.")
        lines.append("")
        lines.append("OPTIONAL — Read the current UI snapshot only if the user explicitly asks about the timeline currently open in the Bobo screen:")
        lines.append("curl -s http://localhost:18790/bobo/timeline")
        lines.append("This endpoint mirrors the currently selected day in the phone UI and may not be 'today'. Always check the returned date field before using it.")
        lines.append("")
        lines.append("WRITE — Add a diary entry to BoBo timeline:")
        lines.append("curl -s -X POST http://localhost:18790/bobo/narrations/add -H 'Content-Type: application/json' -d '{\"transcript\":\"what the user said or described\"}'")
        lines.append("Use this when the user wants to log something to their timeline. Keep transcript concise and factual.")

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
