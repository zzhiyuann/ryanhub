import Foundation

// MARK: - Parking Data Provider

/// Provides parking status and skip date data for chat context injection.
/// Reads directly from parkmobile-auto files (same paths as ParkingViewModel).
enum ParkingDataProvider: ToolkitDataProvider {

    static let toolkitId = "parking"
    static let displayName = "Parking Data"

    static let relevanceKeywords: [String] = [
        "parking", "park", "skip", "car", "commute", "parkmobile",
        "zone", "drive", "driving",
        // Chinese
        "停车", "通勤", "开车"
    ]

    // MARK: - File Paths

    private static let skipDatesFilePath = "/Users/zwang/projects/parkmobile-auto/skip-dates.txt"
    private static let statusFilePath = "/Users/zwang/projects/parkmobile-auto/last-status.json"
    private static let historyFilePath = "/Users/zwang/projects/parkmobile-auto/purchase-history.json"

    static func buildContextSummary() -> String? {
        let skipDates = loadSkipDates()
        let lastStatus = loadLastStatus()
        let history = loadPurchaseHistory()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: today)

        var lines: [String] = ["[\(displayName)]"]

        // Today's status
        let isWeekday = !calendar.isDateInWeekend(today)
        let todaySkipped = skipDates.contains(todayStr)

        if !isWeekday {
            lines.append("Today is a weekend — no parking needed")
        } else if todaySkipped {
            lines.append("Today's parking: SKIPPED")
        } else if let status = lastStatus, status.date == todayStr {
            lines.append("Today's parking: \(status.summary)")
        } else {
            lines.append("Today's parking: Pending (cron not yet run)")
        }

        // Upcoming skip dates
        let upcomingSkips = skipDates
            .compactMap { dateFormatter.date(from: $0) }
            .filter { $0 >= today }
            .sorted()
        if !upcomingSkips.isEmpty {
            let formatted = upcomingSkips.prefix(5).map { date -> String in
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE, MMM d"
                return dayFormatter.string(from: date)
            }
            lines.append("Upcoming skip dates: \(formatted.joined(separator: "; "))")
            if upcomingSkips.count > 5 {
                lines.append("(\(upcomingSkips.count - 5) more)")
            }
        } else {
            lines.append("No upcoming skip dates")
        }

        // Monthly cost
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let currentMonth = monthFormatter.string(from: today)
        let monthCost = history
            .filter { ($0.status == "purchased" || $0.status == "already_active") && $0.date.hasPrefix(currentMonth) }
            .compactMap(\.price)
            .reduce(0, +)
        if monthCost > 0 {
            lines.append("This month's parking cost: $\(String(format: "%.2f", monthCost))")
        }

        let purchasedDays = history
            .filter { ($0.status == "purchased" || $0.status == "already_active") && $0.date.hasPrefix(currentMonth) }
            .count
        if purchasedDays > 0 {
            lines.append("Purchased days this month: \(purchasedDays)")
        }

        // Action hints — tell the agent how to modify parking state
        lines.append("Actions:")
        lines.append("- Skip a date: append YYYY-MM-DD to \(skipDatesFilePath) (one per line, weekdays only)")
        lines.append("- Restore a date: remove the line from \(skipDatesFilePath)")
        lines.append("- View skip list: cat \(skipDatesFilePath)")

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }

    // MARK: - File I/O

    private static func loadSkipDates() -> [String] {
        guard let content = try? String(contentsOfFile: skipDatesFilePath, encoding: .utf8) else {
            return []
        }
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func loadLastStatus() -> ParkingCronStatus? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statusFilePath)) else {
            return nil
        }
        return try? JSONDecoder().decode(ParkingCronStatus.self, from: data)
    }

    private static func loadPurchaseHistory() -> [ParkingCronStatus] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: historyFilePath)) else {
            return []
        }
        return (try? JSONDecoder().decode([ParkingCronStatus].self, from: data)) ?? []
    }

    /// Local decode-only model (avoids dependency on ParkingModels).
    private struct ParkingCronStatus: Decodable {
        let date: String
        let status: String
        let price: Double?

        var summary: String {
            switch status {
            case "purchased": return "Purchased ($\(String(format: "%.2f", price ?? 0)))"
            case "already_active": return "Already parked (manual)"
            case "skipped": return "Skipped"
            case "price_too_high": return "Not bought (price too high)"
            case "error": return "Error"
            default: return status
            }
        }
    }
}
