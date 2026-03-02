import Foundation

// MARK: - BoBo Data Provider

/// Provides BoBo API access instructions for chat context injection.
/// Does NOT inject actual timeline data (too large). Instead tells the agent
/// how to query the bridge server for sensing events, narrations, and summaries
/// on demand when the user asks BoBo-related questions.
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
        lines.append("READ — Query timeline data from bridge server when the user asks about their behavior, activity, health metrics, or diary:")
        lines.append("- Sensing events for a date: curl -s http://localhost:18790/bobo/sensing?date=YYYY-MM-DD")
        lines.append("  Returns JSON array of {id, timestamp, modality, payload}. Modalities: motion, steps, heartRate, hrv, sleep, location, screen, workout, activeEnergy, basalEnergy, respiratoryRate, bloodOxygen, noiseExposure, battery, call, wifi, bluetooth, audio, photo")
        lines.append("- Narrations (diary entries): curl -s http://localhost:18790/bobo/narrations")
        lines.append("  Returns JSON array of {id, timestamp, transcript, duration, affectAnalysis: {mood, energy, stress, primaryEmotion, valence, arousal}}")
        lines.append("- Use today's date if no date specified. Filter and analyze the JSON to answer the user's questions.")
        lines.append("")
        lines.append("WRITE — Add a diary entry to BoBo timeline:")
        lines.append("curl -s -X POST http://localhost:18790/bobo/narrations/add -H 'Content-Type: application/json' -d '{\"transcript\":\"what the user said or described\"}'")
        lines.append("Use this when the user wants to log something to their timeline. Keep transcript concise and factual.")

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
