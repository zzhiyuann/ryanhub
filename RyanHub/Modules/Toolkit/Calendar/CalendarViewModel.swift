import Foundation

// MARK: - Calendar View Model

/// Manages calendar events and syncing with the Dispatcher.
/// Starts with an empty state and syncs via Dispatcher chat commands.
@Observable
final class CalendarViewModel {
    // MARK: - State

    var todayEvents: [CalendarEvent] = []
    var tomorrowEvents: [CalendarEvent] = []
    var weekEvents: [CalendarEvent] = []
    var isLoading = false
    var lastSyncTime: Date?
    var syncState: CalendarSyncState = .idle
    var selectedEvent: CalendarEvent?
    var showEventDetail = false

    // MARK: - Computed

    /// Whether the calendar has any events across all sections.
    var hasAnyEvents: Bool {
        !todayEvents.isEmpty || !tomorrowEvents.isEmpty || !weekEvents.isEmpty
    }

    /// Whether the calendar has ever been synced.
    var hasSynced: Bool {
        lastSyncTime != nil
    }

    /// Formatted last sync time label.
    var lastSyncLabel: String? {
        guard let syncTime = lastSyncTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: syncTime, relativeTo: Date()))"
    }

    /// The next upcoming event (not yet started or currently ongoing).
    var nextUpcomingEvent: CalendarEvent? {
        let now = Date()
        let allEvents = (todayEvents + tomorrowEvents + weekEvents)
            .filter { !$0.isAllDay && $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
        return allEvents.first
    }

    /// Countdown string to the next event (e.g., "in 2h 15m").
    var countdownToNextEvent: String? {
        guard let event = nextUpcomingEvent else { return nil }
        let now = Date()

        if event.isOngoing {
            let remaining = event.endTime.timeIntervalSince(now)
            return "Ends \(formatInterval(remaining))"
        }

        let interval = event.startTime.timeIntervalSince(now)
        guard interval > 0 else { return nil }
        return "Starts \(formatInterval(interval))"
    }

    /// Week overview blocks for the current week (Mon-Sun).
    var weekOverview: [WeekDayBlock] {
        let calendar = Calendar.current
        let today = Date()

        // Find the Monday of the current week
        var monday = today
        while calendar.component(.weekday, from: monday) != 2 {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: monday) else { break }
            monday = prev
        }
        monday = calendar.startOfDay(for: monday)

        let allEvents = todayEvents + tomorrowEvents + weekEvents

        var blocks: [WeekDayBlock] = []
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEvents = allEvents.filter {
                calendar.isDate($0.startTime, inSameDayAs: dayStart)
            }
            blocks.append(WeekDayBlock(date: dayStart, events: dayEvents))
        }

        return blocks
    }

    // MARK: - Init

    init() {
        loadCachedEvents()
    }

    // MARK: - Actions

    /// Sync events by sending a command to the Dispatcher.
    func syncEvents() {
        isLoading = true
        syncState = .syncing

        // Send a command through the chat system to request calendar data
        NotificationCenter.default.post(
            name: .sendChatCommand,
            object: nil,
            userInfo: ["command": "what's on my calendar this week"]
        )

        // Wait for response. In production, the Dispatcher response handler
        // would call updateEvents(). For now, mark sync as complete.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            lastSyncTime = Date()
            isLoading = false
            syncState = .synced
            saveCachedEvents()
        }
    }

    /// Refresh events (called on pull-to-refresh or manual sync).
    func refresh() {
        syncEvents()
    }

    /// Select an event to show its detail view.
    func selectEvent(_ event: CalendarEvent) {
        selectedEvent = event
        showEventDetail = true
    }

    /// Dismiss the event detail view.
    func dismissEventDetail() {
        showEventDetail = false
        selectedEvent = nil
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
        if lastSyncTime != nil {
            syncState = .synced
        }
    }

    // MARK: - Private Helpers

    /// Format a time interval into a human-readable string.
    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "in \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "in \(hours)h"
        } else if minutes > 0 {
            return "in \(minutes)m"
        } else {
            return "now"
        }
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let cachedEvents = "ryanhub_calendar_cached"
    }
}

// MARK: - Cached Data Container

private struct CachedCalendarData: Codable {
    let todayEvents: [CalendarEvent]
    let tomorrowEvents: [CalendarEvent]
    let weekEvents: [CalendarEvent]
    let lastSyncTime: Date?
}
