import Foundation

// MARK: - Calendar Data Provider

/// Provides calendar event data for chat context injection.
/// Reads from UserDefaults cache (same key as CalendarViewModel).
enum CalendarDataProvider: ToolkitDataProvider {

    static let toolkitId = "calendar"
    static let displayName = "Calendar Data"

    static let relevanceKeywords: [String] = [
        "calendar", "event", "meeting", "schedule", "appointment",
        "busy", "free", "available", "tomorrow",
        // Chinese
        "日历", "会议", "安排", "约会", "日程"
    ]

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "ryanhub_calendar_cached") else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cached = try? decoder.decode(CachedCalendarSnapshot.self, from: data) else {
            return nil
        }

        let allEvents = cached.todayEvents + cached.tomorrowEvents + cached.weekEvents
        guard !allEvents.isEmpty else { return nil }

        var lines: [String] = ["[\(displayName)]"]

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"

        // Today's events
        if !cached.todayEvents.isEmpty {
            lines.append("Today's events:")
            for event in cached.todayEvents.sorted(by: { $0.startTime < $1.startTime }) {
                var desc = "- \(event.title)"
                if event.isAllDay {
                    desc += " (All Day)"
                } else {
                    desc += " (\(timeFormatter.string(from: event.startTime)) - \(timeFormatter.string(from: event.endTime)))"
                }
                if let loc = event.location, !loc.isEmpty {
                    desc += " @ \(loc)"
                }
                lines.append(desc)
            }
        } else {
            lines.append("Today: No events")
        }

        // Tomorrow's events
        if !cached.tomorrowEvents.isEmpty {
            lines.append("Tomorrow's events:")
            for event in cached.tomorrowEvents.sorted(by: { $0.startTime < $1.startTime }) {
                var desc = "- \(event.title)"
                if event.isAllDay {
                    desc += " (All Day)"
                } else {
                    desc += " (\(timeFormatter.string(from: event.startTime)) - \(timeFormatter.string(from: event.endTime)))"
                }
                if let loc = event.location, !loc.isEmpty {
                    desc += " @ \(loc)"
                }
                lines.append(desc)
            }
        }

        // Week events (beyond today/tomorrow)
        if !cached.weekEvents.isEmpty {
            lines.append("This week:")
            for event in cached.weekEvents.sorted(by: { $0.startTime < $1.startTime }) {
                var desc = "- \(dayFormatter.string(from: event.startTime)): \(event.title)"
                if !event.isAllDay {
                    desc += " (\(timeFormatter.string(from: event.startTime)))"
                }
                lines.append(desc)
            }
        }

        // Sync freshness
        if let syncTime = cached.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lines.append("(Calendar synced \(formatter.localizedString(for: syncTime, relativeTo: Date())))")
        }

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }

    /// Local Decodable copy of CalendarViewModel's CachedCalendarData
    /// (the original is `private`).
    private struct CachedCalendarSnapshot: Decodable {
        let todayEvents: [CalendarEventSnapshot]
        let tomorrowEvents: [CalendarEventSnapshot]
        let weekEvents: [CalendarEventSnapshot]
        let lastSyncTime: Date?
    }

    /// Local decode-only model matching CalendarEvent's Codable encoding.
    private struct CalendarEventSnapshot: Decodable {
        let id: String
        let title: String
        let startTime: Date
        let endTime: Date
        let location: String?
        let isAllDay: Bool
    }
}
