import Foundation

@Observable
@MainActor
final class HydrationTrackerViewModel {

    // MARK: - State

    var entries: [HydrationTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyGoalOz: Double = 64.0

    // MARK: - Bridge Server

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.double(forKey: "hydrationTracker_dailyGoal")
        dailyGoalOz = saved > 0 ? saved : 64.0
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/hydrationTracker/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([HydrationTrackerEntry].self, from: data)
            entries = decoded.sorted { $0.date > $1.date }
            UserDefaults.standard.set(data, forKey: "dynamic_module_hydrationTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: HydrationTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/hydrationTracker/data/add") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(entry)
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: HydrationTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/hydrationTracker/data?id=\(entry.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveDailyGoal() {
        UserDefaults.standard.set(dailyGoalOz, forKey: "hydrationTracker_dailyGoal")
    }

    // MARK: - Date Helpers

    private func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private var todayKey: String { dayKey(for: Date()) }

    var todayEntries: [HydrationTrackerEntry] {
        entries.filter { $0.dayKey == todayKey }
    }

    private func entries(forDayKey key: String) -> [HydrationTrackerEntry] {
        entries.filter { $0.dayKey == key }
    }

    private func effectiveOz(forDayKey key: String) -> Double {
        entries(forDayKey: key).reduce(0) { $0 + $1.effectiveOz }
    }

    // MARK: - Today Stats

    var todayTotalOz: Double {
        todayEntries.reduce(0) { $0 + $1.amountOz }
    }

    var todayEffectiveOz: Double {
        todayEntries.reduce(0) { $0 + $1.effectiveOz }
    }

    var todayGoalProgress: Double {
        min(1.0, todayEffectiveOz / max(1, dailyGoalOz))
    }

    var todayRemainingOz: Double {
        max(0, dailyGoalOz - todayEffectiveOz)
    }

    var todayEntryCount: Int {
        todayEntries.count
    }

    var todayTotalEffectiveOz: Double { todayEffectiveOz }

    var isGoalMetToday: Bool { todayEffectiveOz >= dailyGoalOz }

    var calendarData: [Date: Double] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var map: [Date: Double] = [:]
        for entry in entries {
            if let d = dateFormatter.date(from: entry.dayKey) {
                map[d, default: 0] += entry.effectiveOz
            }
        }
        return map
    }

    // MARK: - Streak

    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()

        // If today hasn't met the goal yet, start counting from yesterday
        if effectiveOz(forDayKey: todayKey) < dailyGoalOz {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let key = dayKey(for: checkDate)
            if effectiveOz(forDayKey: key) >= dailyGoalOz {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        guard !entries.isEmpty else { return 0 }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let qualifyingDays = Set(entries.map { $0.dayKey })
            .filter { effectiveOz(forDayKey: $0) >= dailyGoalOz }
            .sorted()

        guard !qualifyingDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<qualifyingDays.count {
            guard let prev = dateFormatter.date(from: qualifyingDays[i - 1]),
                  let curr = dateFormatter.date(from: qualifyingDays[i]),
                  let diff = calendar.dateComponents([.day], from: prev, to: curr).day else { continue }

            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    // MARK: - Weekly Stats

    var weeklyAverageOz: Double {
        let calendar = Calendar.current
        let total = (0..<7).compactMap { i -> Double? in
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            return effectiveOz(forDayKey: dayKey(for: date))
        }.reduce(0, +)
        return total / 7
    }

    var weeklyTrendPercent: Double {
        let calendar = Calendar.current
        var thisWeekTotal = 0.0
        var lastWeekTotal = 0.0

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                thisWeekTotal += effectiveOz(forDayKey: dayKey(for: date))
            }
            if let date = calendar.date(byAdding: .day, value: -(i + 7), to: Date()) {
                lastWeekTotal += effectiveOz(forDayKey: dayKey(for: date))
            }
        }

        let lastAvg = lastWeekTotal / 7
        guard lastAvg > 0 else { return 0 }
        return ((thisWeekTotal / 7) - lastAvg) / lastAvg * 100
    }

    // MARK: - Chart Data

    var last7DaysChartData: [(date: Date, oz: Double, goalMet: Bool)] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { i -> (date: Date, oz: Double, goalMet: Bool)? in
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            let key = dayKey(for: date)
            let oz = effectiveOz(forDayKey: key)
            return (date: date, oz: oz, goalMet: oz >= dailyGoalOz)
        }
    }

    // MARK: - Distributions

    var hourlyDistribution: [Int: Double] {
        var dist: [Int: Double] = [:]
        for entry in entries {
            dist[entry.hour, default: 0] += entry.amountOz
        }
        return dist
    }

    var beverageBreakdown: [(type: BeverageType, totalOz: Double, percentage: Double)] {
        var totals: [BeverageType: Double] = [:]
        for entry in entries {
            totals[entry.beverageType, default: 0] += entry.amountOz
        }
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }
        return totals
            .map { (type: $0.key, totalOz: $0.value, percentage: $0.value / grandTotal * 100) }
            .sorted { $0.totalOz > $1.totalOz }
    }

    // MARK: - Goal Achievement Rate (last 30 tracked days)

    var goalAchievementRate: Double {
        let calendar = Calendar.current
        var metCount = 0
        var trackedCount = 0

        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let key = dayKey(for: date)
            guard !entries(forDayKey: key).isEmpty else { continue }
            trackedCount += 1
            if effectiveOz(forDayKey: key) >= dailyGoalOz { metCount += 1 }
        }

        return trackedCount > 0 ? Double(metCount) / Double(trackedCount) : 0
    }

    // MARK: - Time Since Last Drink

    var timeSinceLastDrink: TimeInterval? {
        // entries is sorted descending; todayEntries.first = most recent today
        guard let latest = todayEntries.first, let date = latest.resolvedDate else { return nil }
        return Date().timeIntervalSince(date)
    }

    // MARK: - Best Day of Week

    var bestDayOfWeek: String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Aggregate daily totals by weekday
        var dayKeyTotals: [String: Double] = [:]
        for entry in entries {
            dayKeyTotals[entry.dayKey, default: 0] += entry.effectiveOz
        }

        var weekdaySums: [Int: Double] = [:]
        var weekdayCounts: [Int: Int] = [:]

        for (key, total) in dayKeyTotals {
            guard let date = dateFormatter.date(from: key) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            weekdaySums[weekday, default: 0] += total
            weekdayCounts[weekday, default: 0] += 1
        }

        guard !weekdaySums.isEmpty else { return "Mon" }

        var bestWeekday = 2 // Default Monday (1=Sun)
        var bestAvg = 0.0
        for (weekday, total) in weekdaySums {
            let count = max(1, weekdayCounts[weekday] ?? 1)
            let avg = total / Double(count)
            if avg > bestAvg {
                bestAvg = avg
                bestWeekday = weekday
            }
        }

        // shortWeekdaySymbols is 0-indexed; .weekday is 1-indexed
        return calendar.shortWeekdaySymbols[bestWeekday - 1]
    }

    // MARK: - Insights

    var insights: [HydrationInsight] {
        var result: [HydrationInsight] = []
        let currentHour = Calendar.current.component(.hour, from: Date())

        // Streak milestone: celebrate at 3, 7, 14, 30, 60, 100
        let streak = currentStreak
        if [3, 7, 14, 30, 60, 100].contains(streak) {
            result.append(.streakMilestone(streak: streak))
        }

        // Dehydration warning: past 2pm and < 50% of goal consumed
        if currentHour >= 14 && todayEffectiveOz < dailyGoalOz * 0.5 {
            result.append(.dehydrationWarning(remainingOz: todayRemainingOz))
        }

        // Best day of week (only meaningful with history)
        if !entries.isEmpty {
            result.append(.bestDay(dayName: bestDayOfWeek))
        }

        // Morning hydration: average before 10am is under 16oz
        if !entries.isEmpty && averageMorningIntake() < 16 {
            result.append(.morningHydration())
        }

        // Weekly trend
        let trend = weeklyTrendPercent
        if trend > 10 {
            result.append(.weeklyImprovement(percent: trend))
        } else if trend < -10 {
            result.append(.weeklyDecline(percent: trend))
        }

        // Beverage diversity: single type > 80% of all intake
        if let dominant = beverageBreakdown.first, dominant.percentage > 80 {
            result.append(.beverageDiversity(dominantType: dominant.type))
        }

        // Time gap alert: > 3 hours with no drink, waking hours (8am–10pm)
        if currentHour >= 8 && currentHour <= 22,
           let gap = timeSinceLastDrink, gap > 3 * 3600 {
            result.append(.timeGapAlert(hours: Int(gap / 3600)))
        }

        // Goal consistency: > 90% achievement rate → suggest raising goal
        let rate = goalAchievementRate
        if rate > 0.9 {
            result.append(.goalConsistency(rate: rate, currentGoal: dailyGoalOz))
        }

        return result
    }

    // MARK: - Private Helpers

    private func averageMorningIntake() -> Double {
        let allDays = Set(entries.map { $0.dayKey })
        guard !allDays.isEmpty else { return 0 }

        var morningTotals: [String: Double] = [:]
        for entry in entries where entry.hour < 10 {
            morningTotals[entry.dayKey, default: 0] += entry.effectiveOz
        }

        let total = allDays.reduce(0.0) { $0 + (morningTotals[$1] ?? 0) }
        return total / Double(allDays.count)
    }
}