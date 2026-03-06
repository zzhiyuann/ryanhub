import Foundation

// MARK: - Parking Status

/// Represents the current parking purchase status for a given day.
enum ParkingStatus: String, Codable {
    case active
    case skipped
    case notPurchased
    case unknown

    var displayText: String {
        switch self {
        case .active: return "Active"
        case .skipped: return "Skipped"
        case .notPurchased: return "Not Purchased"
        case .unknown: return "Pending"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .notPurchased: return "circle.dashed"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Parking Skip Entry

/// A single skip date entry for display purposes.
struct ParkingSkipEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date

    var isWeekend: Bool {
        Calendar.current.isDateInWeekend(date)
    }

    /// Whether this skip date is in the past (before today).
    var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var relativeDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return formattedDate
        }
    }

    /// Short day number for calendar grid display (e.g., "25").
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Monthly Parking Stats

/// Tracks parking usage statistics for a given month.
struct MonthlyParkingStats {
    let purchasedDays: Int
    let skippedDays: Int
    let awaitingDays: Int
}

// MARK: - Cron Purchase Status

/// Status of the last cron job execution, read from last-status.json.
struct CronPurchaseStatus: Codable {
    let timestamp: String
    let date: String
    let status: String  // "purchased", "already_active", "skipped", "price_too_high", "error", "login_failed"
    let price: Double?
    let duration: String?
    let maxMinutes: Int?
    let zone: String?
    let vehicle: String?
    let reason: String?
    let limit: Double?

    /// Whether this status is from today.
    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return date == today
    }

    /// Human-readable summary.
    var summary: String {
        switch status {
        case "purchased":
            return "Purchased at $\(String(format: "%.2f", price ?? 0))"
        case "already_active":
            return "Already parked (manual purchase)"
        case "skipped":
            return "Skipped (in skip list)"
        case "price_too_high":
            return "Not bought — $\(String(format: "%.2f", price ?? 0)) >= $\(String(format: "%.0f", limit ?? 4)) limit"
        case "login_failed":
            return "Login failed: \(reason ?? "unknown")"
        case "error":
            return "Error: \(reason ?? "unknown")"
        default:
            return status
        }
    }

    /// SF Symbol icon name.
    var iconName: String {
        switch status {
        case "purchased", "already_active": return "checkmark.circle.fill"
        case "skipped": return "arrow.right.circle.fill"
        case "price_too_high": return "exclamationmark.triangle.fill"
        case "login_failed", "error": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    /// Icon color.
    var iconColorName: String {
        switch status {
        case "purchased", "already_active": return "green"
        case "skipped": return "yellow"
        case "price_too_high": return "orange"
        case "login_failed", "error": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when a toolkit module needs to send a command through the chat system.
    static let sendChatCommand = Notification.Name("sendChatCommand")
}
