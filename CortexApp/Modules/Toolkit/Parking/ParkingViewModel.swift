import Foundation
import SwiftUI

// MARK: - Parking View Model

/// Manages parking skip dates and communicates with the Dispatcher.
/// For MVP, commands are sent as chat messages through NotificationCenter.
@Observable
final class ParkingViewModel {
    // MARK: - State

    var skipDates: [ParkingSkipEntry] = []
    var todayStatus: ParkingStatus = .unknown
    var isLoading = false
    var lastActionMessage: String?
    var showConfirmation = false

    // MARK: - Computed

    /// Upcoming skip dates sorted chronologically, excluding past dates.
    var upcomingSkipDates: [ParkingSkipEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return skipDates
            .filter { Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
    }

    /// Whether today is a weekday (parking is only relevant on weekdays).
    var isTodayWeekday: Bool {
        !Calendar.current.isDateInWeekend(Date())
    }

    /// Whether tomorrow is a weekday.
    var isTomorrowWeekday: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return !Calendar.current.isDateInWeekend(tomorrow)
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
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
            nextMonday = calendar.date(byAdding: .day, value: 1, to: nextMonday)!
        }
        nextMonday = calendar.startOfDay(for: nextMonday)

        // If today is already next week's Monday, advance one more week
        if calendar.isDate(nextMonday, inSameDayAs: Date()) {
            nextMonday = calendar.date(byAdding: .weekOfYear, value: 1, to: nextMonday)!
        }

        sendCommand("skip parking next week")

        for dayOffset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: nextMonday)!
            if !isDateAlreadySkipped(date) {
                skipDates.append(ParkingSkipEntry(date: date))
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDate = calendar.date(byAdding: .day, value: 4, to: nextMonday)!
        showFeedback("Skipping next week (\(formatter.string(from: nextMonday)) - \(formatter.string(from: endDate)))")
        saveSkipDates()
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
    private func isDateAlreadySkipped(_ date: Date) -> Bool {
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
        static let skipDates = "cortex_parking_skip_dates"
    }
}
