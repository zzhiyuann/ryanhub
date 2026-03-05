import Foundation

@Observable
@MainActor
final class FocusTimerViewModel {
    var entries: [FocusTimerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyGoalMinutes: Int = 120

    private var mondayCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/focusTimer/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            entries = try JSONDecoder().decode([FocusTimerEntry].self, from: data)
            UserDefaults.standard.set(data, forKey: "dynamic_module_focusTimer_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: FocusTimerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/focusTimer/data/add") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: FocusTimerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/focusTimer/data?id=\(entry.id)") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Date Filtering

    var todayEntries: [FocusTimerEntry] {
        entries.filter {
            guard let d = $0.entryDate else { return false }
            return Calendar.current.isDateInToday(d)
        }
    }

    private var last7DaysEntries: [FocusTimerEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { ($0.entryDate ?? .distantPast) >= cutoff }
    }

    private var currentWeekEntries: [FocusTimerEntry] {
        guard let interval = mondayCalendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return entries.filter { interval.contains($0.entryDate ?? .distantPast) }
    }

    private var lastWeekEntries: [FocusTimerEntry] {
        guard
            let interval = mondayCalendar.dateInterval(of: .weekOfYear, for: Date()),
            let lastWeekDate = mondayCalendar.date(byAdding: .day, value: -7, to: interval.start),
            let lastInterval = mondayCalendar.dateInterval(of: .weekOfYear, for: lastWeekDate)
        else { return [] }
        return entries.filter { lastInterval.contains($0.entryDate ?? .distantPast) }
    }

    // MARK: - Computed Properties

    var todayTotalMinutes: Int {
        todayEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var todaySessionCount: Int {
        todayEntries.count
    }

    var todayCompletionRate: Double {
        guard !todayEntries.isEmpty else { return 0 }
        return Double(todayEntries.filter { $0.completed }.count) / Double(todayEntries.count)
    }

    var todayGoalProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(todayTotalMinutes) / Double(dailyGoalMinutes))
    }

    var averageFocusQuality: Double {
        guard !last7DaysEntries.isEmpty else { return 0 }
        return Double(last7DaysEntries.reduce(0) { $0 + $1.focusQuality }) / Double(last7DaysEntries.count)
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let dayEntries = entries.filter {
                guard let d = $0.entryDate else { return false }
                return calendar.isDate(d, inSameDayAs: checkDate)
            }
            let hasCompleted = dayEntries.contains { $0.completed }
            let totalMinutes = dayEntries.reduce(0) { $0 + $1.durationMinutes }
            guard hasCompleted && totalMinutes >= 25 else { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var weeklyTotalMinutes: Int {
        currentWeekEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var weeklyTrend: Double {
        let lastMinutes = lastWeekEntries.reduce(0) { $0 + $1.durationMinutes }
        guard lastMinutes > 0 else { return 0 }
        return Double(weeklyTotalMinutes - lastMinutes) / Double(lastMinutes)
    }

    var peakProductivityHour: Int {
        let calendar = Calendar.current
        var hourQualities: [Int: [Int]] = [:]
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.startTime)
            hourQualities[hour, default: []].append(entry.focusQuality)
        }
        guard !hourQualities.isEmpty else { return 9 }
        return hourQualities
            .mapValues { Double($0.reduce(0, +)) / Double($0.count) }
            .max(by: { $0.value < $1.value })?.key ?? 9
    }

    var categoryBreakdown: [(FocusCategory, Int)] {
        var totals: [FocusCategory: Int] = [:]
        for entry in entries {
            totals[entry.category, default: 0] += entry.durationMinutes
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    var averageDistractions: Double {
        guard !last7DaysEntries.isEmpty else { return 0 }
        return Double(last7DaysEntries.reduce(0) { $0 + $1.distractionCount }) / Double(last7DaysEntries.count)
    }

    var chartData: [DailyFocusPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reversed().compactMap { offset -> DailyFocusPoint? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayEntries = entries.filter {
                guard let d = $0.entryDate else { return false }
                return calendar.isDate(d, inSameDayAs: date)
            }
            return DailyFocusPoint(
                date: date,
                totalMinutes: dayEntries.reduce(0) { $0 + $1.durationMinutes },
                sessionCount: dayEntries.count
            )
        }
    }

    var insights: [String] {
        var result: [String] = []

        if !entries.isEmpty {
            result.append("You focus best at \(formatHour(peakProductivityHour)) — schedule deep work then.")
        }

        if let top = categoryBreakdown.first, weeklyTotalMinutes > 0 {
            let topWeekMinutes = currentWeekEntries
                .filter { $0.category == top.0 }
                .reduce(0) { $0 + $1.durationMinutes }
            let pct = Int(Double(topWeekMinutes) / Double(weeklyTotalMinutes) * 100)
            result.append("You spent \(pct)% of focus time on \(top.0.displayName) this week.")
        }

        let thisWeekQuality = qualityAverage(for: currentWeekEntries)
        let lastWeekQuality = qualityAverage(for: lastWeekEntries)
        if lastWeekQuality > 0 {
            let change = Int(((thisWeekQuality - lastWeekQuality) / lastWeekQuality) * 100)
            let direction = change >= 0 ? "improved" : "declined"
            result.append("Your focus quality \(direction) \(abs(change))% vs last week.")
        }

        let prev7Entries = entriesInRange(from: 14, to: 7)
        if !prev7Entries.isEmpty {
            let prevAvg = Double(prev7Entries.reduce(0) { $0 + $1.distractionCount }) / Double(prev7Entries.count)
            if prevAvg > 0 && averageDistractions < prevAvg {
                let pct = Int(((prevAvg - averageDistractions) / prevAvg) * 100)
                result.append("Distractions down \(pct)% — your focus discipline is strengthening.")
            }
        }

        if !entries.isEmpty {
            let rate = Int(Double(entries.filter { $0.completed }.count) / Double(entries.count) * 100)
            result.append("\(rate)% of sessions completed without early termination.")
        }

        let streak = currentStreak
        if streak > 0 {
            result.append("You've maintained focus for \(streak) day\(streak == 1 ? "" : "s") straight — personal best!")
        }

        if let bestType = bestSessionType() {
            result.append("Your highest quality sessions are \(bestType.displayName) — consider using this format more.")
        }

        return result
    }

    // MARK: - Private Helpers

    private func formatHour(_ hour: Int) -> String {
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour):00"
        }
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f.string(from: date)
    }

    private func qualityAverage(for entries: [FocusTimerEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.focusQuality }) / Double(entries.count)
    }

    private func entriesInRange(from daysAgoStart: Int, to daysAgoEnd: Int) -> [FocusTimerEntry] {
        let calendar = Calendar.current
        guard
            let start = calendar.date(byAdding: .day, value: -daysAgoStart, to: Date()),
            let end = calendar.date(byAdding: .day, value: -daysAgoEnd, to: Date())
        else { return [] }
        return entries.filter {
            guard let d = $0.entryDate else { return false }
            return d >= start && d < end
        }
    }

    private func bestSessionType() -> SessionType? {
        var typeQualities: [SessionType: [Int]] = [:]
        for entry in entries {
            typeQualities[entry.sessionType, default: []].append(entry.focusQuality)
        }
        return typeQualities
            .mapValues { Double($0.reduce(0, +)) / Double($0.count) }
            .max(by: { $0.value < $1.value })?.key
    }
}