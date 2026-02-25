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
        case .unknown: return "Unknown"
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
    let totalWeekdays: Int
    let skippedDays: Int
    let activeDays: Int
    let costPerDay: Double

    /// Fraction of the month's weekdays that have been active (0.0 to 1.0).
    var usageRatio: Double {
        guard totalWeekdays > 0 else { return 0 }
        return Double(activeDays) / Double(totalWeekdays)
    }

    /// Total estimated savings from skipping.
    var estimatedSavings: Double {
        Double(skippedDays) * costPerDay
    }

    /// Total estimated cost for active days.
    var estimatedCost: Double {
        Double(activeDays) * costPerDay
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when a toolkit module needs to send a command through the chat system.
    static let sendChatCommand = Notification.Name("sendChatCommand")
}
