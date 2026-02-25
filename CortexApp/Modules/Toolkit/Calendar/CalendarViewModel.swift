import Foundation

// MARK: - Calendar View Model

/// Manages calendar events and syncing with the Dispatcher.
/// For MVP, provides placeholder data with a sync button that sends a chat command.
@Observable
final class CalendarViewModel {
    // MARK: - State

    var todayEvents: [CalendarEvent] = []
    var tomorrowEvents: [CalendarEvent] = []
    var weekEvents: [CalendarEvent] = []
    var isLoading = false
    var lastSyncTime: Date?
    var syncError: String?

    // MARK: - Computed

    /// Whether the calendar has any events across all sections.
    var hasAnyEvents: Bool {
        !todayEvents.isEmpty || !tomorrowEvents.isEmpty || !weekEvents.isEmpty
    }

    /// Formatted last sync time label.
    var lastSyncLabel: String? {
        guard let syncTime = lastSyncTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: syncTime, relativeTo: Date()))"
    }

    // MARK: - Init

    init() {
        loadCachedEvents()
    }

    // MARK: - Actions

    /// Sync events by sending a command to the Dispatcher.
    func syncEvents() {
        isLoading = true
        syncError = nil

        // Send a command through the chat system to request calendar data
        NotificationCenter.default.post(
            name: .sendChatCommand,
            object: nil,
            userInfo: ["command": "what's on my calendar this week"]
        )

        // For MVP, populate with sample data after a brief delay
        // In production, this would parse the Dispatcher response
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            populateSampleData()
            lastSyncTime = Date()
            isLoading = false
            saveCachedEvents()
        }
    }

    /// Refresh events (called on pull-to-refresh or manual sync).
    func refresh() {
        syncEvents()
    }

    // MARK: - Persistence (MVP: UserDefaults cache)

    private func saveCachedEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(CachedCalendarData(
            todayEvents: todayEvents,
            tomorrowEvents: tomorrowEvents,
            weekEvents: weekEvents,
            lastSyncTime: lastSyncTime
        )) {
            UserDefaults.standard.set(data, forKey: StorageKeys.cachedEvents)
        }
    }

    private func loadCachedEvents() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.cachedEvents) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cached = try? decoder.decode(CachedCalendarData.self, from: data) else { return }
        todayEvents = cached.todayEvents
        tomorrowEvents = cached.tomorrowEvents
        weekEvents = cached.weekEvents
        lastSyncTime = cached.lastSyncTime
    }

    // MARK: - Sample Data (MVP)

    /// Populate with sample events for demonstration.
    /// In production, this data comes from the Dispatcher (Google Calendar MCP).
    private func populateSampleData() {
        let calendar = Calendar.current
        let today = Date()

        // Today's events
        todayEvents = [
            CalendarEvent(
                title: "Team Standup",
                startTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
                endTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
                location: "Zoom",
                calendarColor: "6366F1"
            ),
            CalendarEvent(
                title: "Lunch with Luyuan",
                startTime: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!,
                endTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today)!,
                location: "The Corner",
                calendarColor: "22C55E"
            ),
            CalendarEvent(
                title: "Research Seminar",
                startTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
                endTime: calendar.date(bySettingHour: 16, minute: 30, second: 0, of: today)!,
                location: "Rice Hall 340",
                calendarColor: "F59E0B"
            ),
        ]

        // Tomorrow's events
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        tomorrowEvents = [
            CalendarEvent(
                title: "Advisor Meeting",
                startTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!,
                endTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: tomorrow)!,
                location: "Rice Hall 512",
                calendarColor: "EF4444"
            ),
            CalendarEvent(
                title: "Gym Session",
                startTime: calendar.date(bySettingHour: 17, minute: 30, second: 0, of: tomorrow)!,
                endTime: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: tomorrow)!,
                calendarColor: "22C55E"
            ),
        ]

        // This week's remaining events
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
        let threeDaysOut = calendar.date(byAdding: .day, value: 3, to: today)!
        weekEvents = [
            CalendarEvent(
                title: "Paper Deadline",
                startTime: calendar.startOfDay(for: dayAfterTomorrow),
                endTime: calendar.startOfDay(for: dayAfterTomorrow),
                calendarColor: "EF4444",
                isAllDay: true
            ),
            CalendarEvent(
                title: "Lab Meeting",
                startTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: threeDaysOut)!,
                endTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: threeDaysOut)!,
                location: "Online",
                calendarColor: "6366F1"
            ),
        ]
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let cachedEvents = "cortex_calendar_cached"
    }
}

// MARK: - Cached Data Container

private struct CachedCalendarData: Codable {
    let todayEvents: [CalendarEvent]
    let tomorrowEvents: [CalendarEvent]
    let weekEvents: [CalendarEvent]
    let lastSyncTime: Date?
}
