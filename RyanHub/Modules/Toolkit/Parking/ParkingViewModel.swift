import Foundation
import SwiftUI

// MARK: - Parking View Model

/// Manages parking skip dates, calendar picker, cost tracking, and
/// communicates with the Dispatcher via NotificationCenter commands.
@Observable
final class ParkingViewModel {
    // MARK: - Constants

    /// Cost per day for Zone 5556 parking.
    static let costPerDay: Double = 3.50

    // MARK: - State

    var skipDates: [ParkingSkipEntry] = []
    var todayStatus: ParkingStatus = .unknown
    var isLoading = false
    var lastActionMessage: String?
    var showConfirmation = false

    /// The month currently displayed in the calendar picker.
    var calendarDisplayedMonth: Date = Date()

    // MARK: - Computed

    /// Upcoming skip dates sorted chronologically, excluding past dates.
    var upcomingSkipDates: [ParkingSkipEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return skipDates
            .filter { Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
    }

    /// Past skip dates sorted reverse chronologically.
    var pastSkipDates: [ParkingSkipEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return skipDates
            .filter { Calendar.current.startOfDay(for: $0.date) < today }
            .sorted { $0.date > $1.date }
    }

    /// Whether today is a weekday (parking is only relevant on weekdays).
    var isTodayWeekday: Bool {
        !Calendar.current.isDateInWeekend(Date())
    }

    /// Whether tomorrow is a weekday.
    var isTomorrowWeekday: Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return false }
        return !Calendar.current.isDateInWeekend(tomorrow)
    }

    /// Smart suggestion: if today is Friday, suggest skipping next Monday.
    var smartSuggestion: SmartSuggestion? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // weekday: 1 = Sunday, 6 = Friday, 7 = Saturday
        if weekday == 6 {
            // Today is Friday, suggest next Monday
            guard let nextMonday = calendar.date(byAdding: .day, value: 3, to: Date()) else { return nil }
            let mondayStart = calendar.startOfDay(for: nextMonday)
            if !isDateAlreadySkipped(mondayStart) {
                return SmartSuggestion(
                    title: "Skip Next Monday",
                    subtitle: "You usually don't park on Mondays after a weekend",
                    icon: "lightbulb.fill",
                    date: mondayStart
                )
            }
        }
        return nil
    }

    /// Monthly stats for the current calendar month.
    var currentMonthStats: MonthlyParkingStats {
        computeMonthStats(for: Date())
    }

    /// Monthly stats for the displayed calendar month.
    var displayedMonthStats: MonthlyParkingStats {
        computeMonthStats(for: calendarDisplayedMonth)
    }

    /// Total lifetime savings from all skip dates.
    var totalSavings: Double {
        Double(skipDates.count) * Self.costPerDay
    }

    // MARK: - Init

    init() {
        loadSkipDates()
        updateTodayStatus()
    }

    // MARK: - Actions

    /// Skip parking for today.
    func skipToday() {
        guard isTodayWeekday else { return }
        let today = Calendar.current.startOfDay(for: Date())
        guard !isDateAlreadySkipped(today) else { return }

        sendCommand("skip parking today")
        skipDates.append(ParkingSkipEntry(date: today))
        todayStatus = .skipped
        showFeedback("Skipping parking for today")
        saveSkipDates()
    }

    /// Skip parking for tomorrow.
    func skipTomorrow() {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        let tomorrowStart = Calendar.current.startOfDay(for: tomorrow)
        guard !Calendar.current.isDateInWeekend(tomorrowStart) else { return }
        guard !isDateAlreadySkipped(tomorrowStart) else { return }

        sendCommand("skip parking tomorrow")
        skipDates.append(ParkingSkipEntry(date: tomorrowStart))
        showFeedback("Skipping parking for tomorrow")
        saveSkipDates()
    }

    /// Skip parking for all weekdays next week (Monday through Friday).
    func skipNextWeek() {
        let calendar = Calendar.current
        // Find next Monday
        var nextMonday = Date()
        while calendar.component(.weekday, from: nextMonday) != 2 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: nextMonday) else { return }
            nextMonday = next
        }
        nextMonday = calendar.startOfDay(for: nextMonday)

        // If today is already next week's Monday, advance one more week
        if calendar.isDate(nextMonday, inSameDayAs: Date()) {
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: nextMonday) else { return }
            nextMonday = next
        }

        sendCommand("skip parking next week")

        for dayOffset in 0..<5 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: nextMonday) else { continue }
            if !isDateAlreadySkipped(date) {
                skipDates.append(ParkingSkipEntry(date: date))
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDate = calendar.date(byAdding: .day, value: 4, to: nextMonday) ?? nextMonday
        showFeedback("Skipping next week (\(formatter.string(from: nextMonday)) - \(formatter.string(from: endDate)))")
        saveSkipDates()
    }

    /// Toggle skip status for a specific date (used by the calendar picker).
    func toggleDate(_ date: Date) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Only allow toggling weekdays that are today or in the future
        guard !calendar.isDateInWeekend(dayStart) else { return }
        guard dayStart >= calendar.startOfDay(for: Date()) else { return }

        if isDateAlreadySkipped(dayStart) {
            // Restore
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: dayStart)
            sendCommand("restore parking \(dateString)")
            skipDates.removeAll { calendar.isDate($0.date, inSameDayAs: dayStart) }
            if calendar.isDateInToday(dayStart) {
                todayStatus = .active
            }
            showFeedback("Restored parking for \(ParkingSkipEntry(date: dayStart).relativeDateLabel)")
        } else {
            // Skip
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: dayStart)
            sendCommand("skip parking \(dateString)")
            skipDates.append(ParkingSkipEntry(date: dayStart))
            if calendar.isDateInToday(dayStart) {
                todayStatus = .skipped
            }
            showFeedback("Skipping parking for \(ParkingSkipEntry(date: dayStart).relativeDateLabel)")
        }

        saveSkipDates()
    }

    /// Apply the smart suggestion.
    func applySmartSuggestion() {
        guard let suggestion = smartSuggestion else { return }
        toggleDate(suggestion.date)
    }

    /// Restore (un-skip) a specific date.
    func restoreDate(_ entry: ParkingSkipEntry) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: entry.date)
        sendCommand("restore parking \(dateString)")

        skipDates.removeAll { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
        if Calendar.current.isDateInToday(entry.date) {
            todayStatus = .unknown
        }
        showFeedback("Restored parking for \(entry.relativeDateLabel)")
        saveSkipDates()
    }

    /// Navigate to the previous month in the calendar picker.
    func previousMonth() {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayedMonth) else { return }
        calendarDisplayedMonth = prev
    }

    /// Navigate to the next month in the calendar picker.
    func nextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: calendarDisplayedMonth) else { return }
        calendarDisplayedMonth = next
    }

    // MARK: - Calendar Helpers

    /// Check if a specific date has been skipped.
    func isDateSkipped(_ date: Date) -> Bool {
        isDateAlreadySkipped(date)
    }

    /// Get all days of the displayed month arranged as a grid (with leading empty slots).
    var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarDisplayedMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: calendarDisplayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        // weekday: 1 = Sunday. We want Monday=0, so adjust.
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        // Convert to Monday-based index: Mon=0, Tue=1, ..., Sun=6
        let leadingEmpties = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmpties)

        for day in monthRange {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDay) {
                days.append(calendar.startOfDay(for: date))
            }
        }

        return days
    }

    /// Formatted month/year label for the calendar header.
    var displayedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: calendarDisplayedMonth)
    }

    // MARK: - Data Persistence (MVP: UserDefaults)

    /// Load skip dates from local storage.
    func loadSkipDates() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.skipDates),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else {
            return
        }
        skipDates = dates.map { ParkingSkipEntry(date: $0) }
    }

    /// Save skip dates to local storage.
    private func saveSkipDates() {
        let dates = skipDates.map(\.date)
        if let data = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(data, forKey: StorageKeys.skipDates)
        }
    }

    // MARK: - Private

    /// Check if a date is already in the skip list.
    func isDateAlreadySkipped(_ date: Date) -> Bool {
        skipDates.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// Update today's status based on skip dates.
    private func updateTodayStatus() {
        let today = Calendar.current.startOfDay(for: Date())
        if !isTodayWeekday {
            todayStatus = .notPurchased
        } else if isDateAlreadySkipped(today) {
            todayStatus = .skipped
        } else {
            todayStatus = .active
        }
    }

    /// Compute stats for a given month.
    private func computeMonthStats(for referenceDate: Date) -> MonthlyParkingStats {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate),
              let monthRange = calendar.range(of: .day, in: .month, for: referenceDate) else {
            return MonthlyParkingStats(totalWeekdays: 0, skippedDays: 0, activeDays: 0, costPerDay: Self.costPerDay)
        }

        let firstDay = monthInterval.start
        var totalWeekdays = 0
        var skippedDays = 0

        for day in monthRange {
            guard let date = calendar.date(bySetting: .day, value: day, of: firstDay) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            if !calendar.isDateInWeekend(dayStart) {
                totalWeekdays += 1
                if isDateAlreadySkipped(dayStart) {
                    skippedDays += 1
                }
            }
        }

        let activeDays = totalWeekdays - skippedDays
        return MonthlyParkingStats(
            totalWeekdays: totalWeekdays,
            skippedDays: skippedDays,
            activeDays: activeDays,
            costPerDay: Self.costPerDay
        )
    }

    /// Send a command to the Dispatcher through the chat system.
    private func sendCommand(_ command: String) {
        NotificationCenter.default.post(
            name: .sendChatCommand,
            object: nil,
            userInfo: ["command": command]
        )
    }

    /// Show a brief feedback message.
    private func showFeedback(_ message: String) {
        lastActionMessage = message
        showConfirmation = true
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let skipDates = "ryanhub_parking_skip_dates"
    }
}

// MARK: - Smart Suggestion

/// A context-aware parking suggestion.
struct SmartSuggestion {
    let title: String
    let subtitle: String
    let icon: String
    let date: Date
}
