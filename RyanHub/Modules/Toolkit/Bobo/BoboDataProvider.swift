import Foundation

// MARK: - BoBo Data Provider

/// Provides BoBo timeline data for chat context injection.
/// Uses a static cache populated by BoboViewModel after loading.
enum BoboDataProvider: ToolkitDataProvider {

    static let toolkitId = "bobo"
    static let displayName = "BoBo Timeline Data"

    static let relevanceKeywords: [String] = [
        "bobo", "timeline", "sensing", "narration", "behavior", "movement",
        "activity", "motion", "walking", "driving", "stationary", "sleep",
        "heart rate", "steps", "screen time", "location", "mood", "emotion",
        "diary", "journal", "today", "yesterday", "schedule", "routine",
        // Chinese
        "行为", "活动", "运动", "走路", "开车", "心率", "步数",
        "日记", "情绪", "心情", "时间线", "作息"
    ]

    // MARK: - Cache

    /// Lightweight snapshot of today's timeline data, populated by BoboViewModel.
    struct Snapshot {
        let date: Date
        let summary: SummaryData
        let motionEpisodes: [MotionEpisode]
        let narrations: [NarrationSnippet]
        let healthHighlights: [HealthHighlight]

        struct SummaryData {
            let totalSteps: Int
            let activityBreakdown: [String: Int]
            let locationChanges: Int
            let screenEvents: Int
            let narrationCount: Int
            let eventCount: Int
            let totalCaloriesConsumed: Int
            let totalActivityMinutes: Int
            let totalCaloriesBurned: Int
        }

        struct MotionEpisode {
            let time: String         // e.g., "9:15 AM"
            let activity: String     // e.g., "walking"
            let duration: String?    // e.g., "15 min"
            let nextActivity: String? // e.g., "driving"
        }

        struct NarrationSnippet {
            let time: String
            let transcript: String   // Truncated to ~100 chars
            let primaryEmotion: String?
            let mood: Int?           // 1-10
        }

        struct HealthHighlight {
            let metric: String       // e.g., "Heart Rate"
            let value: String        // e.g., "72 bpm"
        }
    }

    /// Cache populated by BoboViewModel on data changes.
    @MainActor static var cachedSnapshot: Snapshot?

    // MARK: - Build Context

    static func buildContextSummary() -> String? {
        let snapshot = MainActor.assumeIsolated { cachedSnapshot }

        guard let snapshot else {
            // BoBo not loaded yet — still provide action hints
            var lines: [String] = ["[\(displayName)]"]
            lines.append("BoBo sensing not loaded yet (user hasn't opened BoBo tab).")
            appendActionHints(to: &lines)
            lines.append("[End \(displayName)]")
            return lines.joined(separator: "\n")
        }

        var lines: [String] = ["[\(displayName)]"]

        let dateStr = Self.formatDate(snapshot.date)
        lines.append("Date: \(dateStr)")

        // Day summary
        let s = snapshot.summary
        lines.append("Events: \(s.eventCount) total")
        if s.totalSteps > 0 {
            lines.append("Steps: \(s.totalSteps)")
        }
        if !s.activityBreakdown.isEmpty {
            let breakdown = s.activityBreakdown
                .sorted { $0.value > $1.value }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            lines.append("Activity: \(breakdown)")
        }
        if s.locationChanges > 0 {
            lines.append("Location changes: \(s.locationChanges)")
        }
        if s.screenEvents > 0 {
            lines.append("Screen events: \(s.screenEvents)")
        }
        if s.totalCaloriesConsumed > 0 {
            lines.append("Calories consumed: \(s.totalCaloriesConsumed) cal")
        }
        if s.totalActivityMinutes > 0 {
            var actLine = "Exercise: \(s.totalActivityMinutes) min"
            if s.totalCaloriesBurned > 0 {
                actLine += ", \(s.totalCaloriesBurned) cal burned"
            }
            lines.append(actLine)
        }

        // Motion timeline
        if !snapshot.motionEpisodes.isEmpty {
            lines.append("")
            lines.append("Activity Timeline:")
            for ep in snapshot.motionEpisodes {
                var desc = "- \(ep.time): \(ep.activity)"
                if let dur = ep.duration {
                    desc += " (\(dur))"
                }
                if let next = ep.nextActivity {
                    desc += " → \(next)"
                }
                lines.append(desc)
            }
        }

        // Health highlights
        if !snapshot.healthHighlights.isEmpty {
            lines.append("")
            lines.append("Health Metrics:")
            for h in snapshot.healthHighlights {
                lines.append("- \(h.metric): \(h.value)")
            }
        }

        // Narrations
        if !snapshot.narrations.isEmpty {
            lines.append("")
            lines.append("Diary Entries (\(snapshot.summary.narrationCount) total):")
            for nar in snapshot.narrations.prefix(5) {
                var desc = "- \(nar.time): \"\(nar.transcript)\""
                if let emotion = nar.primaryEmotion {
                    desc += " [emotion: \(emotion)]"
                }
                if let mood = nar.mood {
                    desc += " [mood: \(mood)/10]"
                }
                lines.append(desc)
            }
        }

        // Action hints
        lines.append("")
        appendActionHints(to: &lines)

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func appendActionHints(to lines: inout [String]) {
        lines.append("Actions — To add a diary entry / text narration to BoBo timeline:")
        lines.append("curl -s -X POST http://localhost:18790/bobo/narrations/add -H 'Content-Type: application/json' -d '{\"transcript\":\"what the user said or described\"}'")
        lines.append("Timestamp defaults to now. Keep the transcript concise and factual. Use this when the user wants to log something to their BoBo timeline.")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
