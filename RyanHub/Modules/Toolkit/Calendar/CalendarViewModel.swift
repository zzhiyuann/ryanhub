import Foundation

// MARK: - Calendar View Model

/// Manages calendar events with real Google Calendar integration via the sync server.
@MainActor @Observable
final class CalendarViewModel {
    // MARK: - State

    var allEvents: [CalendarEvent] = []
    var calendars: [CalendarInfo] = []
    var isLoading = false
    var lastSyncTime: Date?
    var syncState: CalendarSyncState = .idle
    var selectedEvent: CalendarEvent?
    var showEventDetail = false

    // Long-press delete
    var eventToDelete: CalendarEvent?
    var showDeleteConfirmation = false

    // AI command input
    var commandText = ""
    var isProcessingCommand = false
    var agentResponse: AgentCalendarResponse?
    var commandError: String?

    // Service
    let service: CalendarService

    // MARK: - Computed: Filtered Event Lists

    var todayEvents: [CalendarEvent] {
        let calendar = Calendar.current
        return allEvents.filter { calendar.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    var tomorrowEvents: [CalendarEvent] {
        let calendar = Calendar.current
        return allEvents.filter { calendar.isDateInTomorrow($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    var weekEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }
        return allEvents.filter { $0.startTime >= dayAfterTomorrow && $0.startTime < weekEnd }
            .sorted { $0.startTime < $1.startTime }
    }

    var hasAnyEvents: Bool {
        !allEvents.isEmpty
    }

    var hasSynced: Bool {
        lastSyncTime != nil
    }

    var lastSyncLabel: String? {
        guard let syncTime = lastSyncTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: syncTime, relativeTo: Date()))"
    }

    var nextUpcomingEvent: CalendarEvent? {
        let now = Date()
        return allEvents
            .filter { !$0.isAllDay && $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    var countdownToNextEvent: String? {
        guard let event = nextUpcomingEvent else { return nil }
        let now = Date()
        if event.isOngoing {
            return "Ends \(formatInterval(event.endTime.timeIntervalSince(now)))"
        }
        let interval = event.startTime.timeIntervalSince(now)
        guard interval > 0 else { return nil }
        return "Starts \(formatInterval(interval))"
    }

    var weekOverview: [WeekDayBlock] {
        let calendar = Calendar.current
        let today = Date()

        var monday = today
        while calendar.component(.weekday, from: monday) != 2 {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: monday) else { break }
            monday = prev
        }
        monday = calendar.startOfDay(for: monday)

        var blocks: [WeekDayBlock] = []
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEvents = allEvents.filter { calendar.isDate($0.startTime, inSameDayAs: dayStart) }
            blocks.append(WeekDayBlock(date: dayStart, events: dayEvents))
        }
        return blocks
    }

    /// Events grouped by day (for "This Week" section).
    var eventsByDay: [(date: Date, events: [CalendarEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: weekEvents) { calendar.startOfDay(for: $0.startTime) }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, events: $0.value) }
    }

    // MARK: - Init

    init(service: CalendarService = CalendarService()) {
        self.service = service
        loadCachedEvents()
    }

    // MARK: - Actions

    /// Sync events from Apple Calendar via the bridge server.
    func syncEvents() async {
        // Guard against re-entry but with a safety timeout
        guard !isLoading else { return }
        isLoading = true
        syncState = .syncing

        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            guard let endOfWeek = calendar.date(byAdding: .day, value: 8, to: startOfToday) else {
                syncState = .error("Failed to compute date range")
                return
            }

            // Fetch calendars and events in parallel
            async let calendarsFetch = service.fetchCalendars()
            async let eventsFetch = service.fetchEvents(start: startOfToday, end: endOfWeek)

            calendars = try await calendarsFetch
            allEvents = try await eventsFetch
            lastSyncTime = Date()
            syncState = .synced
            saveCachedEvents()
            print("[Calendar] Synced: \(calendars.count) calendars, \(allEvents.count) events")
        } catch {
            print("[Calendar] Sync failed: \(error)")
            syncState = .error(error.localizedDescription)
        }
    }

    /// Process a natural language command via the AI agent.
    func processCommand() async {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isProcessingCommand = true
        commandError = nil
        agentResponse = nil
        commandText = ""

        do {
            let response = try await service.processNaturalLanguage(text)
            agentResponse = response

            // If the agent mutated something, re-sync
            if response.isMutating {
                await syncEvents()
            }
        } catch {
            commandError = error.localizedDescription
        }

        isProcessingCommand = false
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

    /// Delete an event.
    func deleteEvent(_ event: CalendarEvent) async {
        do {
            try await service.deleteEvent(
                eventId: event.id,
                calendarId: event.calendarId ?? "primary"
            )
            dismissEventDetail()
            await syncEvents()
        } catch {
            commandError = "Failed to delete: \(error.localizedDescription)"
        }
    }

    /// Request deletion of an event via long-press (shows confirmation).
    func confirmDeleteEvent(_ event: CalendarEvent) {
        eventToDelete = event
        showDeleteConfirmation = true
    }

    /// Execute the pending long-press deletion.
    func executeDeleteEvent() async {
        guard let event = eventToDelete else { return }
        await deleteEvent(event)
        eventToDelete = nil
    }

    /// Dismiss the agent response card.
    func dismissAgentResponse() {
        agentResponse = nil
        commandError = nil
    }

    // MARK: - Persistence (UserDefaults cache)

    private func saveCachedEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(CachedCalendarData(
            allEvents: allEvents,
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
        allEvents = cached.allEvents
        lastSyncTime = cached.lastSyncTime
        if lastSyncTime != nil {
            syncState = .synced
        }
    }

    // MARK: - Private Helpers

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

    private enum StorageKeys {
        static let cachedEvents = "ryanhub_calendar_cached"
    }
}

// MARK: - Cached Data Container

private struct CachedCalendarData: Codable {
    let allEvents: [CalendarEvent]
    let lastSyncTime: Date?
}
