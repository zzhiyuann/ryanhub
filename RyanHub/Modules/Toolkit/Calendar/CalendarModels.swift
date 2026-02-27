import SwiftUI

// MARK: - Calendar Event

/// Represents a single calendar event from Google Calendar.
struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let location: String?
    let notes: String?
    let calendarId: String?
    let calendarName: String?
    let calendarColor: String?
    let isAllDay: Bool
    let htmlLink: String?
    let status: String?
    let attendees: [EventAttendee]?

    init(
        id: String = UUID().uuidString,
        title: String,
        startTime: Date,
        endTime: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarId: String? = nil,
        calendarName: String? = nil,
        calendarColor: String? = nil,
        isAllDay: Bool = false,
        htmlLink: String? = nil,
        status: String? = nil,
        attendees: [EventAttendee]? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.notes = notes
        self.calendarId = calendarId
        self.calendarName = calendarName
        self.calendarColor = calendarColor
        self.isAllDay = isAllDay
        self.htmlLink = htmlLink
        self.status = status
        self.attendees = attendees
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
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

    /// Formatted full date string (e.g., "Wednesday, Feb 26").
    var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: startTime)
    }

    /// Duration in minutes.
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    /// Formatted duration string (e.g., "1h 30m").
    var formattedDuration: String {
        if isAllDay { return "All Day" }
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Resolved calendar color for display.
    var resolvedColor: Color {
        guard let hex = calendarColor else { return .hubPrimary }
        return Color(hex: hex)
    }

    /// Whether this event has already ended.
    var hasEnded: Bool {
        endTime < Date()
    }

    /// Whether this event is currently happening.
    var isOngoing: Bool {
        let now = Date()
        return startTime <= now && endTime >= now
    }

    /// Apple Maps URL for the location, if available.
    var mapsURL: URL? {
        guard let location = location, !location.isEmpty else { return nil }
        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    /// Google Calendar URL for this event.
    var googleCalendarURL: URL? {
        guard let link = htmlLink else { return nil }
        return URL(string: link)
    }
}

// MARK: - Event Attendee

struct EventAttendee: Codable, Hashable {
    let email: String
    let displayName: String?
    let responseStatus: String

    var statusLabel: String {
        switch responseStatus {
        case "accepted": return "Accepted"
        case "declined": return "Declined"
        case "tentative": return "Maybe"
        case "needsAction": return "Pending"
        default: return responseStatus.capitalized
        }
    }

    var statusColor: Color {
        switch responseStatus {
        case "accepted": return .hubAccentGreen
        case "declined": return .hubAccentRed
        case "tentative": return .hubAccentYellow
        default: return .secondary
        }
    }
}

// MARK: - Calendar Info

/// Metadata about a Google Calendar.
struct CalendarInfo: Codable, Identifiable {
    let id: String
    let summary: String
    let backgroundColor: String
    let primary: Bool
    let accessRole: String

    var resolvedColor: Color {
        Color(hex: backgroundColor)
    }
}

// MARK: - Agent Response

/// Response from the calendar agent (natural language processing).
struct AgentCalendarResponse: Codable {
    let message: String
    let action: String
    let eventId: String?

    var isError: Bool {
        action == "error"
    }

    var isMutating: Bool {
        ["created", "updated", "deleted"].contains(action)
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

// MARK: - Calendar Sync State

/// Represents the sync state of the calendar.
enum CalendarSyncState: Equatable {
    case idle
    case syncing
    case synced
    case error(String)
}

// MARK: - Week Day Block

/// Represents a time block in the week overview.
struct WeekDayBlock: Identifiable {
    let id = UUID()
    let date: Date
    let events: [CalendarEvent]

    /// Day-of-week abbreviation (e.g., "Mon").
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Day number (e.g., "25").
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    /// Whether this day is today.
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Total busy hours for this day.
    var busyHours: Double {
        let totalMinutes = events.filter { !$0.isAllDay }.reduce(0) { $0 + $1.durationMinutes }
        return Double(totalMinutes) / 60.0
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
