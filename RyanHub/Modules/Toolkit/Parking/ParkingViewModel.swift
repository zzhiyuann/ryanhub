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

    /// Purchase history loaded from purchase-history.json.
    var purchaseHistory: [CronPurchaseStatus] = []

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

    /// Whether today is a weekday (parking is only relevant on weekdays).
    var isTodayWeekday: Bool {
        !Calendar.current.isDateInWeekend(Date())
    }

    /// Whether tomorrow is a weekday.
    var isTomorrowWeekday: Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return false }
        return !Calendar.current.isDateInWeekend(tomorrow)
    }

    /// Monthly stats for the current calendar month.
    var currentMonthStats: MonthlyParkingStats {
        computeMonthStats(for: Date())
    }

    /// Actual cost this month from purchase history.
    var currentMonthCost: Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        return purchaseHistory
            .filter { ($0.status == "purchased" || $0.status == "already_active") && $0.date.hasPrefix(currentMonth) }
            .compactMap(\.price)
            .reduce(0, +)
    }

    /// Estimated "until" time for today's active parking.
    /// Uses maxMinutes (preferred) or parses duration string to compute end time.
    var parkingUntilTime: String {
        guard let cron = lastCronStatus, cron.isToday,
              (cron.status == "purchased" || cron.status == "already_active") else {
            return "Until --:--"
        }
        if cron.status == "already_active" {
            return "Manually purchased — duration unknown"
        }
        guard let totalMinutes = cron.maxMinutes ?? Self.parseDurationMinutes(cron.duration) else {
            return "Until --:--"
        }
        guard let purchaseTime = Self.parseTimestamp(cron.timestamp) else {
            return "Until --:--"
        }
        let endTime = purchaseTime.addingTimeInterval(TimeInterval(totalMinutes * 60))
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        return "Until \(tf.string(from: endTime))"
    }

    /// Remaining parking time as a fraction (0.0 to 1.0), for progress display.
    var parkingTimeRemaining: (fraction: Double, label: String) {
        guard let cron = lastCronStatus, cron.isToday,
              (cron.status == "purchased" || cron.status == "already_active"),
              let totalMinutes = cron.maxMinutes ?? Self.parseDurationMinutes(cron.duration) else {
            return (0, "--:--")
        }
        let totalSeconds = Double(totalMinutes * 60)
        guard let start = Self.parseTimestamp(cron.timestamp) else { return (0, "--:--") }
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
        loadPurchaseHistory()
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

    /// Check if a specific date has a successful purchase in the history.
    func isDatePurchased(_ date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        return purchaseHistory.contains { $0.date == dateStr && ($0.status == "purchased" || $0.status == "already_active") }
    }

    /// Get all days of the displayed month arranged as a grid (with leading empty slots).
    var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarDisplayedMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: calendarDisplayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        // Sunday-based index: Sun=0, Mon=1, ..., Sat=6
        let leadingEmpties = firstWeekday - 1

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

    // MARK: - Data Persistence (HTTP API via bridge server)

    /// Base URL for the bridge server (same as food analysis server).
    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

    /// Load skip dates from the bridge server.
    func loadSkipDates() {
        Task {
            do {
                let url = URL(string: "\(bridgeBaseURL)/parking/skip-dates")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                skipDates = content.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .compactMap { formatter.date(from: $0) }
                    .map { ParkingSkipEntry(date: $0) }
            } catch {
                skipDates = []
            }
        }
    }

    /// Write all skip dates back via the bridge server.
    private func saveSkipDates() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStrings = skipDates
            .map(\.date)
            .sorted()
            .map { formatter.string(from: $0) }
        Task {
            do {
                let url = URL(string: "\(bridgeBaseURL)/parking/skip-dates")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(["dates": dateStrings])
                let _ = try await URLSession.shared.data(for: request)
            } catch {
                // Silent fail — data will reload on next open
            }
        }
    }

    // MARK: - Duration/Timestamp Helpers

    /// Parse a duration string into total minutes.
    /// Handles both formats: "5 Hours, 27 Minutes" (legacy) and "5h 27m" (new API).
    static func parseDurationMinutes(_ duration: String?) -> Int? {
        guard let duration, !duration.isEmpty else { return nil }
        var hours = 0
        var minutes = 0
        let lower = duration.lowercased()

        if lower.contains("hour") || lower.contains("minute") {
            // Legacy format: "5 Hours, 27 Minutes"
            let parts = lower.components(separatedBy: ",")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("hour") {
                    hours = Int(trimmed.components(separatedBy: " ").first ?? "") ?? 0
                } else if trimmed.contains("minute") {
                    minutes = Int(trimmed.components(separatedBy: " ").first ?? "") ?? 0
                }
            }
        } else if lower.contains("h") || lower.contains("m") {
            // New format: "2h", "2h 3m", "45m"
            let scanner = Scanner(string: lower)
            while !scanner.isAtEnd {
                if let num = scanner.scanInt() {
                    if scanner.scanString("h") != nil {
                        hours = num
                    } else if scanner.scanString("m") != nil {
                        minutes = num
                    }
                } else {
                    _ = scanner.scanCharacter()
                }
            }
        }

        let total = hours * 60 + minutes
        return total > 0 ? total : nil
    }

    /// Parse an ISO 8601 timestamp string into a Date.
    static func parseTimestamp(_ timestamp: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: timestamp) { return date }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: timestamp)
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
            case "purchased", "already_active":
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

    /// Compute stats for a given month from purchase history and skip dates.
    private func computeMonthStats(for referenceDate: Date) -> MonthlyParkingStats {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let monthPrefix = monthFormatter.string(from: referenceDate)

        // Purchased/skipped from actual logs
        let monthEntries = purchaseHistory.filter { $0.date.hasPrefix(monthPrefix) }
        let purchasedDays = monthEntries.filter { $0.status == "purchased" || $0.status == "already_active" }.count
        let logSkippedDays = monthEntries.filter { $0.status == "skipped" }.count

        // Future skip dates in this month (from skip-dates.txt, not yet in logs)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let logDates = Set(monthEntries.map(\.date))
        let futureSkippedDays = skipDates.filter { entry in
            let dateStr = dateFormatter.string(from: entry.date)
            return dateStr.hasPrefix(monthPrefix) && !logDates.contains(dateStr)
        }.count

        let skippedDays = logSkippedDays + futureSkippedDays

        // Awaiting: future weekdays in this month not yet purchased/skipped/skip-listed
        let today = calendar.startOfDay(for: Date())
        let skipDateStrings = Set(skipDates.map { dateFormatter.string(from: $0.date) })
        guard let monthRange = calendar.range(of: .day, in: .month, for: referenceDate),
              let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) else {
            return MonthlyParkingStats(purchasedDays: 0, skippedDays: 0, awaitingDays: 0)
        }
        let firstDay = monthInterval.start
        var awaitingDays = 0
        for dayOffset in 0..<monthRange.count {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            if dayStart <= today { continue }
            if calendar.isDateInWeekend(dayStart) { continue }
            let dateStr = dateFormatter.string(from: dayStart)
            if !logDates.contains(dateStr) && !skipDateStrings.contains(dateStr) {
                awaitingDays += 1
            }
        }

        return MonthlyParkingStats(
            purchasedDays: purchasedDays,
            skippedDays: skippedDays,
            awaitingDays: awaitingDays
        )
    }

    /// Load the last cron job status from the bridge server.
    func loadCronStatus() {
        Task {
            do {
                let url = URL(string: "\(bridgeBaseURL)/parking/last-status")!
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !data.isEmpty else { lastCronStatus = nil; return }
                lastCronStatus = try JSONDecoder().decode(CronPurchaseStatus.self, from: data)
            } catch {
                lastCronStatus = nil
            }
        }
    }

    /// Load purchase history from the bridge server.
    private func loadPurchaseHistory() {
        Task {
            do {
                let url = URL(string: "\(bridgeBaseURL)/parking/purchase-history")!
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !data.isEmpty else { purchaseHistory = []; return }
                purchaseHistory = try JSONDecoder().decode([CronPurchaseStatus].self, from: data)
            } catch {
                purchaseHistory = []
            }
        }
    }

    /// Show a brief feedback message.
    private func showFeedback(_ message: String) {
        lastActionMessage = message
        showConfirmation = true
    }
}

