import Foundation
import SwiftUI

// MARK: - Parking View Model

/// Manages parking skip dates, calendar picker, and cost tracking.
/// Reads/writes skip dates directly to the parkmobile-auto skip-dates.txt file.
@Observable
@MainActor
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

    /// Last purchase/skip status from the parkmobile-auto cron job.
    var lastCronStatus: CronPurchaseStatus?

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

    /// Estimated "until" time for today's active parking.
    /// Parses cron status timestamp + duration to compute end time.
    var parkingUntilTime: String {
        guard let cron = lastCronStatus, cron.isToday, cron.status == "purchased",
              let duration = cron.duration else {
            return "Until --:--"
        }
        // Parse duration like "5 Hours, 27 Minutes"
        var hours = 0
        var minutes = 0
        let parts = duration.lowercased().components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("hour") {
                hours = Int(trimmed.components(separatedBy: " ").first ?? "") ?? 0
            } else if trimmed.contains("minute") {
                minutes = Int(trimmed.components(separatedBy: " ").first ?? "") ?? 0
            }
        }
        // Parse purchase timestamp
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let purchaseTime = isoFormatter.date(from: cron.timestamp) else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            guard let pt = isoFormatter.date(from: cron.timestamp) else {
                return "Until --:--"
            }
            let endTime = pt.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return "Until \(tf.string(from: endTime))"
        }
        let endTime = purchaseTime.addingTimeInterval(TimeInterval(hours * 3600 + minutes * 60))
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        return "Until \(tf.string(from: endTime))"
    }

    /// Remaining parking time as a fraction (0.0 to 1.0), for progress display.
    var parkingTimeRemaining: (fraction: Double, label: String) {
        guard let cron = lastCronStatus, cron.isToday, cron.status == "purchased",
              let duration = cron.duration else {
            return (0, "--:--")
        }
        var hours = 0
        var minutes = 0
        let parts = duration.lowercased().components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("hour") {
                hours = Int(trimmed.components(separatedBy: " ").first ?? "") ?? 0
            } else if trimmed.contains("minute") {
                minutes = Int(trimmed.components(separatedBy: " ").first ?? "") ?? 0
            }
        }
        let totalSeconds = Double(hours * 3600 + minutes * 60)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var purchaseTime = isoFormatter.date(from: cron.timestamp)
        if purchaseTime == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            purchaseTime = isoFormatter.date(from: cron.timestamp)
        }
        guard let start = purchaseTime else { return (0, "--:--") }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = max(0, totalSeconds - elapsed)
        let fraction = totalSeconds > 0 ? remaining / totalSeconds : 0

        let remHours = Int(remaining) / 3600
        let remMins = (Int(remaining) % 3600) / 60
        let label = remHours > 0 ? "\(remHours)h \(remMins)m" : "\(remMins)m"
        return (fraction, label)
    }

    // MARK: - Init

    init() {
        loadSkipDates()
        loadCronStatus()
        updateTodayStatus()
    }

    // MARK: - Actions

    /// Skip parking for today.
    func skipToday() {
        guard isTodayWeekday else { return }
        let today = Calendar.current.startOfDay(for: Date())
        guard !isDateAlreadySkipped(today) else { return }

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
            skipDates.removeAll { calendar.isDate($0.date, inSameDayAs: dayStart) }
            if calendar.isDateInToday(dayStart) {
                todayStatus = .active
            }
            showFeedback("Restored parking for \(ParkingSkipEntry(date: dayStart).relativeDateLabel)")
        } else {
            // Skip
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

        for dayOffset in 0..<monthRange.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) {
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

    // MARK: - Data Persistence (File I/O)

    /// Path to the skip-dates file used by the parkmobile-auto system.
    private let skipDatesFilePath = "/Users/zwang/projects/parkmobile-auto/skip-dates.txt"

    /// Path to the last status file written by buy.js / run.sh.
    private let statusFilePath = "/Users/zwang/projects/parkmobile-auto/last-status.json"

    /// Load skip dates from the skip-dates.txt file.
    func loadSkipDates() {
        guard let content = try? String(contentsOfFile: skipDatesFilePath, encoding: .utf8) else {
            skipDates = []
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        skipDates = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { formatter.date(from: $0) }
            .map { ParkingSkipEntry(date: $0) }
    }

    /// Write all skip dates back to the skip-dates.txt file, sorted chronologically.
    private func saveSkipDates() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let lines = skipDates
            .map(\.date)
            .sorted()
            .map { formatter.string(from: $0) }
        let content = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        try? content.write(toFile: skipDatesFilePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Private

    /// Check if a date is already in the skip list.
    func isDateAlreadySkipped(_ date: Date) -> Bool {
        skipDates.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// Update today's status based on skip dates and actual cron purchase result.
    private func updateTodayStatus() {
        let today = Calendar.current.startOfDay(for: Date())
        if !isTodayWeekday {
            todayStatus = .notPurchased
        } else if isDateAlreadySkipped(today) {
            todayStatus = .skipped
        } else if let cron = lastCronStatus, cron.isToday {
            // Use actual cron job result to determine status
            switch cron.status {
            case "purchased":
                todayStatus = .active
            case "skipped":
                todayStatus = .skipped
            case "price_too_high", "error", "login_failed":
                todayStatus = .notPurchased
            default:
                todayStatus = .unknown
            }
        } else {
            // Weekday, not skipped, but cron hasn't run yet today
            todayStatus = .unknown
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

        for dayOffset in 0..<monthRange.count {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else { continue }
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

    /// Load the last cron job status from last-status.json.
    func loadCronStatus() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statusFilePath)),
              let status = try? JSONDecoder().decode(CronPurchaseStatus.self, from: data) else {
            lastCronStatus = nil
            return
        }
        lastCronStatus = status
    }

    /// Show a brief feedback message.
    private func showFeedback(_ message: String) {
        lastActionMessage = message
        showConfirmation = true
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
