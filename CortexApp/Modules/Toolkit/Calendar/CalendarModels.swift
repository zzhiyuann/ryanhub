import SwiftUI

// MARK: - Calendar Event

/// Represents a single calendar event.
struct CalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let location: String?
    let calendarColor: String? // hex color
    let isAllDay: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        startTime: Date,
        endTime: Date,
        location: String? = nil,
        calendarColor: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.calendarColor = calendarColor
        self.isAllDay = isAllDay
    }

    /// Formatted time range string (e.g., "9:00 AM - 10:30 AM").
    var formattedTimeRange: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    /// Formatted start time only.
    var formattedStartTime: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }

    /// Duration in minutes.
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    /// Resolved calendar color for display.
    var resolvedColor: Color {
        guard let hex = calendarColor else { return .cortexPrimary }
        return Color(hex: hex)
    }
}

// MARK: - Calendar Section

/// Groups events by time period for display.
enum CalendarSection: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case thisWeek

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        }
    }
}

// MARK: - Color Hex Init (for calendar colors)

extension Color {
    /// Initialize a Color from a hex string. Supports 6-character hex (RGB).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
