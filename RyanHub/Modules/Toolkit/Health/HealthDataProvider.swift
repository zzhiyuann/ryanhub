import Foundation

// MARK: - Health Data Provider

/// Provides formatted health data summaries for injection into chat context.
/// Reads directly from UserDefaults (same keys as HealthViewModel) so it can be
/// used standalone without requiring a shared HealthViewModel instance.
enum HealthDataProvider: ToolkitDataProvider {

    static let toolkitId = "health"
    static let displayName = "Health Data"

    static let relevanceKeywords: [String] = [
        "calories", "calorie", "weight", "food", "ate", "eating", "eat",
        "meal", "exercise", "activity", "workout", "health", "nutrition",
        "protein", "carbs", "carb", "fat", "fitness", "bmi", "diet",
        "breakfast", "lunch", "dinner", "snack",
        "体重", "卡路里", "热量", "蛋白质", "碳水", "脂肪",
        "运动", "锻炼", "健康", "饮食", "早餐", "午餐", "晚餐"
    ]

    static func isRelevant(to text: String) -> Bool {
        isHealthRelated(text)
    }

    // MARK: - Public API

    /// Check whether a message text contains health-related keywords.
    static func isHealthRelated(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return healthKeywords.contains { lowered.contains($0) }
    }

    /// Build a formatted health context summary from persisted data.
    /// Returns `nil` if there is no health data to include.
    static func buildContextSummary() -> String? {
        let weightSection = buildWeightSection()
        let foodSection = buildFoodSection()
        let activitySection = buildActivitySection()

        // If all sections are empty, no context to inject
        if weightSection == nil && foodSection == nil && activitySection == nil {
            return nil
        }

        var parts: [String] = ["[\(displayName)]"]
        if let w = weightSection { parts.append(w) }
        if let f = foodSection { parts.append(f) }
        if let a = activitySection { parts.append(a) }
        parts.append("[End \(displayName)]")

        return parts.joined(separator: "\n")
    }

    // MARK: - Keywords

    private static let healthKeywords: [String] = [
        "calories", "calorie", "weight", "food", "ate", "eating", "eat",
        "meal", "exercise", "activity", "workout", "health", "nutrition",
        "protein", "carbs", "carb", "fat", "fitness", "bmi", "diet",
        "breakfast", "lunch", "dinner", "snack",
        // Chinese keywords for bilingual support
        "体重", "卡路里", "热量", "蛋白质", "碳水", "脂肪",
        "运动", "锻炼", "健康", "饮食", "早餐", "午餐", "晚餐"
    ]

    // MARK: - UserDefaults Keys (mirror HealthViewModel.StorageKeys)

    private static let weightKey = "ryanhub_health_weight"
    private static let foodKey = "ryanhub_health_food"
    private static let activityKey = "ryanhub_health_activity"

    // MARK: - Decoder

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Weight Section

    private static func buildWeightSection() -> String? {
        guard let data = UserDefaults.standard.data(forKey: weightKey),
              let entries = try? decoder.decode([WeightEntry].self, from: data),
              !entries.isEmpty else {
            return nil
        }

        let sorted = entries.sorted { $0.date > $1.date }
        guard let latest = sorted.first else { return nil }

        var lines: [String] = []
        lines.append("Current Weight: \(String(format: "%.1f", latest.weight)) kg (recorded \(relativeDate(latest.date)))")

        // Weekly trend: last 7 entries
        let recentEntries = Array(sorted.prefix(7).reversed())
        if recentEntries.count >= 2 {
            let trend = recentEntries.map { String(format: "%.1f", $0.weight) }.joined(separator: " -> ")
            let change = recentEntries.last!.weight - recentEntries.first!.weight
            let changeStr = change >= 0
                ? "+\(String(format: "%.1f", change))"
                : String(format: "%.1f", change)
            lines.append("Recent Weight Trend: \(trend) kg (\(changeStr) kg over \(recentEntries.count) entries)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Food Section

    private static func buildFoodSection() -> String? {
        guard let data = UserDefaults.standard.data(forKey: foodKey),
              let entries = try? decoder.decode([FoodEntry].self, from: data),
              !entries.isEmpty else {
            return nil
        }

        let calendar = Calendar.current

        // Today's food
        let todayEntries = entries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }

        // Yesterday's food (for additional context)
        let yesterdayEntries = entries
            .filter { calendar.isDateInYesterday($0.date) }
            .sorted { $0.date < $1.date }

        if todayEntries.isEmpty && yesterdayEntries.isEmpty {
            return nil
        }

        var lines: [String] = []

        if !todayEntries.isEmpty {
            lines.append("Today's Food:")
            for entry in todayEntries {
                var desc = "- \(entry.mealType.displayName): \(entry.description)"
                var macros: [String] = []
                if let cal = entry.calories { macros.append("\(cal) cal") }
                if let p = entry.protein { macros.append("\(p)g P") }
                if let c = entry.carbs { macros.append("\(c)g C") }
                if let f = entry.fat { macros.append("\(f)g F") }
                if !macros.isEmpty {
                    desc += " (\(macros.joined(separator: ", ")))"
                }
                lines.append(desc)
            }

            // Totals
            let totalCal = todayEntries.compactMap(\.calories).reduce(0, +)
            let totalP = todayEntries.compactMap(\.protein).reduce(0, +)
            let totalC = todayEntries.compactMap(\.carbs).reduce(0, +)
            let totalF = todayEntries.compactMap(\.fat).reduce(0, +)
            lines.append("Today's Totals: \(totalCal) cal, \(totalP)g protein, \(totalC)g carbs, \(totalF)g fat")
        }

        if !yesterdayEntries.isEmpty {
            let totalCal = yesterdayEntries.compactMap(\.calories).reduce(0, +)
            let totalP = yesterdayEntries.compactMap(\.protein).reduce(0, +)
            let totalC = yesterdayEntries.compactMap(\.carbs).reduce(0, +)
            let totalF = yesterdayEntries.compactMap(\.fat).reduce(0, +)
            lines.append("Yesterday's Totals: \(totalCal) cal, \(totalP)g protein, \(totalC)g carbs, \(totalF)g fat")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Activity Section

    private static func buildActivitySection() -> String? {
        guard let data = UserDefaults.standard.data(forKey: activityKey),
              let entries = try? decoder.decode([ActivityEntry].self, from: data),
              !entries.isEmpty else {
            return nil
        }

        let calendar = Calendar.current

        let todayEntries = entries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }

        let yesterdayEntries = entries
            .filter { calendar.isDateInYesterday($0.date) }

        if todayEntries.isEmpty && yesterdayEntries.isEmpty {
            return nil
        }

        var lines: [String] = []

        if !todayEntries.isEmpty {
            lines.append("Today's Activity:")
            for entry in todayEntries {
                var desc = "- \(entry.type)"
                if entry.duration > 0 {
                    desc += ": \(entry.duration) min"
                }
                if let cal = entry.caloriesBurned, cal > 0 {
                    desc += " (\(cal) cal)"
                } else if let note = entry.note, !note.isEmpty {
                    desc += " (\(note))"
                }
                lines.append(desc)

                // Include exercise breakdown when available
                if !entry.exercises.isEmpty {
                    for exercise in entry.exercises {
                        var exDesc = "  · \(exercise.name)"
                        if let sets = exercise.sets, let reps = exercise.reps {
                            exDesc += ": \(sets) sets × \(reps) reps"
                        }
                        if let weight = exercise.weight {
                            exDesc += " @ \(weight)"
                        }
                        if let dur = exercise.duration {
                            exDesc += ": \(dur) min"
                        }
                        if let cal = exercise.caloriesBurned {
                            exDesc += " (\(cal) cal)"
                        }
                        lines.append(exDesc)
                    }
                }
            }
            let totalMin = todayEntries.map(\.duration).reduce(0, +)
            let totalCal = todayEntries.compactMap(\.caloriesBurned).reduce(0, +)
            var totalLine = "Total activity today: \(totalMin) min"
            if totalCal > 0 {
                totalLine += ", \(totalCal) cal burned"
            }
            lines.append(totalLine)
        }

        if !yesterdayEntries.isEmpty {
            let totalMin = yesterdayEntries.map(\.duration).reduce(0, +)
            lines.append("Yesterday's activity: \(totalMin) min total")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Format a date as a human-readable relative string (e.g. "today", "yesterday", "3 days ago").
    private static func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days) days ago"
        }
    }
}
