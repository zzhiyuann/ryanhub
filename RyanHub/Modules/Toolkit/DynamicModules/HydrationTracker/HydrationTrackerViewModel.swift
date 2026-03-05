import Foundation

// MARK: - HydrationTrackerViewModel

@Observable
@MainActor
final class HydrationTrackerViewModel {

    // MARK: - State

    var entries: [HydrationTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyGoalMl: Int = HydrationTrackerConstants.defaultDailyGoalMl

    // MARK: - Bridge URL

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    // MARK: - Init

    init() {
        dailyGoalMl = UserDefaults.standard.integer(forKey: "hydrationTracker_dailyGoalMl").nonZero
            ?? HydrationTrackerConstants.defaultDailyGoalMl
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
            entries = decoded
            UserDefaults.standard.set(data, forKey: "dynamic_module_hydrationTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: HydrationTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/hydrationTracker/data/add") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: HydrationTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/hydrationTracker/data?id=\(entry.id)") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            entries.removeAll { $0.id == entry.id }
            if let data = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(data, forKey: "dynamic_module_hydrationTracker_cache")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDailyGoal(_ newGoal: Int) {
        dailyGoalMl = newGoal
        UserDefaults.standard.set(newGoal, forKey: "hydrationTracker_dailyGoalMl")
    }

    // MARK: - Date Helpers

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }

    private func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func date(from dayKey: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dayKey)
    }

    private func entriesByDay() -> [String: [HydrationTrackerEntry]] {
        Dictionary(grouping: entries, by: { $0.dayKey })
    }

    private func totalMl(for dayKey: String, in grouped: [String: [HydrationTrackerEntry]]) -> Int {
        (grouped[dayKey] ?? []).reduce(0) { $0 + $1.amountMl }
    }

    private func isActiveDay(_ dayKey: String, grouped: [String: [HydrationTrackerEntry]]) -> Bool {
        Double(totalMl(for: dayKey, in: grouped)) >= Double(dailyGoalMl) * HydrationTrackerConstants.streakThresholdPercent
    }

    // MARK: - Today

    var todayEntries: [HydrationTrackerEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.timeConsumed) }
            .sorted { $0.timeConsumed > $1.timeConsumed }
    }

    var todayTotalMl: Int {
        todayEntries.reduce(0) { $0 + $1.amountMl }
    }

    var todayProgress: Double {
        min(Double(todayTotalMl) / Double(dailyGoalMl), 1.0)
    }

    var todayGlassCount: Int {
        todayEntries.count
    }

    // MARK: - Streak

    var currentStreak: Int {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let today = dayKey(for: Date())
        let yesterday = dayKey(for: cal.date(byAdding: .day, value: -1, to: Date())!)

        // Start from today if active, else yesterday (grace: may not have logged today yet)
        let startKey = isActiveDay(today, grouped: grouped) ? today : yesterday
        guard isActiveDay(startKey, grouped: grouped) else { return 0 }

        var streak = 0
        var cursor = startKey
        var gracePeriodUsed = false

        for _ in 0..<365 {
            if isActiveDay(cursor, grouped: grouped) {
                streak += 1
                gracePeriodUsed = false
            } else if !gracePeriodUsed && grouped[cursor] == nil {
                // Grace period: one empty day doesn't break streak
                gracePeriodUsed = true
            } else {
                break
            }
            guard let cursorDate = date(from: cursor),
                  let prevDate = cal.date(byAdding: .day, value: -1, to: cursorDate) else { break }
            cursor = dayKey(for: prevDate)
        }

        return streak
    }

    var longestStreak: Int {
        let cal = Calendar.current
        let grouped = entriesByDay()
        guard !entries.isEmpty else { return 0 }

        // Build sorted list of all day keys that have entries
        let allKeys = grouped.keys.sorted()
        guard !allKeys.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        var gracePeriodUsed = false
        var previousKey: String? = nil

        for key in allKeys {
            if let prev = previousKey,
               let prevDate = date(from: prev),
               let keyDate = date(from: key) {
                let diff = cal.dateComponents([.day], from: prevDate, to: keyDate).day ?? 0
                if diff == 1 {
                    // Consecutive day
                    gracePeriodUsed = false
                } else if diff == 2 && !gracePeriodUsed {
                    // Gap of 1 — grace period
                    gracePeriodUsed = true
                } else {
                    // Streak broke
                    longest = max(longest, current)
                    current = 0
                    gracePeriodUsed = false
                }
            }

            if isActiveDay(key, grouped: grouped) {
                current += 1
            } else {
                longest = max(longest, current)
                current = 0
                gracePeriodUsed = false
            }

            previousKey = key
        }
        longest = max(longest, current)
        return longest
    }

    // MARK: - Weekly Stats

    private func last7DayKeys() -> [String] {
        let cal = Calendar.current
        return (0..<7).map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return dayKey(for: d)
        }.reversed()
    }

    private func prev7DayKeys() -> [String] {
        let cal = Calendar.current
        return (7..<14).map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return dayKey(for: d)
        }.reversed()
    }

    var weeklyAverageMl: Int {
        let grouped = entriesByDay()
        let keys = last7DayKeys()
        let total = keys.reduce(0) { $0 + totalMl(for: $1, in: grouped) }
        return total / 7
    }

    var weeklyTrendPercent: Double {
        let grouped = entriesByDay()
        let thisWeek = last7DayKeys().reduce(0.0) { $0 + Double(totalMl(for: $1, in: grouped)) } / 7.0
        let lastWeek = prev7DayKeys().reduce(0.0) { $0 + Double(totalMl(for: $1, in: grouped)) } / 7.0
        guard lastWeek > 0 else { return thisWeek > 0 ? 100.0 : 0.0 }
        return ((thisWeek - lastWeek) / lastWeek) * 100.0
    }

    var weeklyChartData: [(day: String, amount: Int, goal: Int)] {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).map { offset -> (day: String, amount: Int, goal: Int) in
            let date = cal.date(byAdding: .day, value: -(6 - offset), to: Date())!
            let key = dayKey(for: date)
            let label = formatter.string(from: date)
            return (day: label, amount: totalMl(for: key, in: grouped), goal: dailyGoalMl)
        }
    }

    var monthlyChartData: [(date: Date, amount: Int)] {
        let cal = Calendar.current
        let grouped = entriesByDay()
        return (0..<30).map { offset -> (date: Date, amount: Int) in
            let d = cal.date(byAdding: .day, value: -(29 - offset), to: Date())!
            let key = dayKey(for: d)
            return (date: d, amount: totalMl(for: key, in: grouped))
        }
    }

    // MARK: - Beverage Breakdown

    var beverageBreakdown: [(type: BeverageType, totalMl: Int, percentage: Double)] {
        var totals = [BeverageType: Int]()
        for entry in entries {
            totals[entry.beverageType, default: 0] += entry.amountMl
        }
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }
        return totals
            .map { (type: $0.key, totalMl: $0.value, percentage: Double($0.value) / Double(grandTotal)) }
            .sorted { $0.totalMl > $1.totalMl }
    }

    // MARK: - Hourly Distribution

    var hourlyDistribution: [Int] {
        let grouped = entriesByDay()
        let allDayKeys = Array(grouped.keys)
        guard !allDayKeys.isEmpty else { return [Int](repeating: 0, count: 24) }

        var buckets = [Int](repeating: 0, count: 24)
        let cal = Calendar.current
        for entry in entries {
            let hour = cal.component(.hour, from: entry.timeConsumed)
            buckets[hour] += entry.amountMl
        }

        // Average across tracked days
        let dayCount = allDayKeys.count
        return buckets.map { $0 / dayCount }
    }

    // MARK: - Goal Completion Rate (last 30 days)

    var goalCompletionRate: Double {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let keys = (0..<30).map { offset -> String in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return dayKey(for: d)
        }
        // Only count days that have at least some data
        let trackedKeys = keys.filter { grouped[$0] != nil }
        guard !trackedKeys.isEmpty else { return 0 }
        let metCount = trackedKeys.filter { isActiveDay($0, grouped: grouped) }.count
        return Double(metCount) / Double(trackedKeys.count)
    }

    // MARK: - Best Day

    var bestDayRecord: (date: Date, amount: Int)? {
        let grouped = entriesByDay()
        guard !grouped.isEmpty else { return nil }
        let best = grouped
            .map { (key: $0.key, total: $0.value.reduce(0) { $0 + $1.amountMl }) }
            .max { $0.total < $1.total }
        guard let best = best, let d = date(from: best.key) else { return nil }
        return (date: d, amount: best.total)
    }

    // MARK: - Caffeine Ratio (this week)

    var caffeineToWaterRatio: Double {
        let grouped = entriesByDay()
        let keys = last7DayKeys()
        let weekEntries = keys.flatMap { grouped[$0] ?? [] }
        let totalMl = weekEntries.reduce(0) { $0 + $1.amountMl }
        guard totalMl > 0 else { return 0 }
        let caffeinatedMl = weekEntries.filter { $0.effectivelyCaffeinated }.reduce(0) { $0 + $1.amountMl }
        return Double(caffeinatedMl) / Double(totalMl)
    }

    // MARK: - Insights

    var hydrationInsights: [InsightItem] {
        var insights: [InsightItem] = []

        // 1. Streak milestone celebration
        let streak = currentStreak
        if HydrationTrackerConstants.streakMilestones.contains(streak) {
            insights.append(InsightItem(
                title: "\(streak)-Day Streak!",
                detail: "You've hit your hydration goal for \(streak) days in a row. Keep it up!",
                icon: "flame.fill",
                priority: .high
            ))
        } else if streak > 0 {
            insights.append(InsightItem(
                title: "\(streak)-Day Streak",
                detail: "You're on a roll — \(streak) consecutive days meeting your goal.",
                icon: "flame",
                priority: .medium
            ))
        }

        // 2. Weekly trend direction
        let trend = weeklyTrendPercent
        let weekAvg = weeklyAverageMl
        let prevAvg = {
            let grouped = entriesByDay()
            let prev = prev7DayKeys().reduce(0.0) { $0 + Double(totalMl(for: $1, in: grouped)) } / 7.0
            return Int(prev)
        }()
        let mlDiff = weekAvg - prevAvg
        if abs(trend) >= 5 {
            let direction = trend > 0 ? "more" : "less"
            let absDiff = abs(mlDiff)
            insights.append(InsightItem(
                title: trend > 0 ? "Trending Up" : "Trending Down",
                detail: "You drank \(absDiff)ml \(direction) per day this week compared to last week.",
                icon: trend > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                priority: trend > 0 ? .low : .medium
            ))
        }

        // 3. Caffeine ratio alert
        let caffeineRatio = caffeineToWaterRatio
        if caffeineRatio > HydrationTrackerConstants.caffeineRatioWarningThreshold {
            let pct = Int(caffeineRatio * 100)
            insights.append(InsightItem(
                title: "High Caffeine Ratio",
                detail: "\(pct)% of your weekly intake is caffeinated. Consider balancing with more plain water.",
                icon: "exclamationmark.triangle.fill",
                priority: .high
            ))
        }

        // 4. Weekend vs weekday comparison
        let weekdayAvg = weekdayAverageMl()
        let weekendAvg = weekendAverageMl()
        if weekdayAvg > 0 && weekendAvg > 0 {
            let diff = abs(weekdayAvg - weekendAvg)
            let pct = Int(Double(diff) / Double(max(weekdayAvg, weekendAvg)) * 100)
            if pct >= 20 {
                let lower = weekdayAvg > weekendAvg ? "weekends" : "weekdays"
                insights.append(InsightItem(
                    title: "Weekend Hydration Gap",
                    detail: "You drink ~\(pct)% less on \(lower). Try to keep consistent all week.",
                    icon: "calendar",
                    priority: .medium
                ))
            }
        }

        // 5. Peak hydration hour
        let dist = hourlyDistribution
        if let maxVal = dist.max(), maxVal > 0, let peakHour = dist.firstIndex(of: maxVal) {
            let nextHour = (peakHour + 1) % 24
            let fmt = DateFormatter()
            fmt.dateFormat = "h a"
            let start = Calendar.current.date(bySettingHour: peakHour, minute: 0, second: 0, of: Date())!
            let end = Calendar.current.date(bySettingHour: nextHour, minute: 0, second: 0, of: Date())!
            insights.append(InsightItem(
                title: "Peak Hydration Hour",
                detail: "You hydrate most between \(fmt.string(from: start))–\(fmt.string(from: end)). Spreading it out helps more.",
                icon: "clock.fill",
                priority: .low
            ))
        }

        // 6. Consistency score (14-day std deviation)
        let consistencyDetail = consistencyInsightDetail()
        if let detail = consistencyDetail {
            insights.append(InsightItem(
                title: "Consistency",
                detail: detail,
                icon: "chart.bar.fill",
                priority: .low
            ))
        }

        // 7. Beverage diversity
        let breakdown = beverageBreakdown
        if let top = breakdown.first, top.type != .water && top.percentage > 0.5 {
            let pct = Int(top.percentage * 100)
            insights.append(InsightItem(
                title: "Beverage Diversity",
                detail: "Try mixing in more plain water — \(pct)% of your intake is \(top.type.displayName).",
                icon: "drop.fill",
                priority: .medium
            ))
        }

        // 8. Goal adjustment suggestion
        let grouped = entriesByDay()
        let last14Keys = (0..<14).map { offset -> String in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            return dayKey(for: d)
        }
        let trackedLast14 = last14Keys.filter { grouped[$0] != nil }
        if trackedLast14.count >= 7 {
            let avg14 = trackedLast14.reduce(0) { $0 + totalMl(for: $1, in: grouped) } / trackedLast14.count
            let ratio = Double(avg14) / Double(dailyGoalMl)
            if ratio > HydrationTrackerConstants.goalRaiseSuggestionMultiple {
                let suggested = Int(Double(dailyGoalMl) * 1.15 / 50) * 50
                insights.append(InsightItem(
                    title: "Raise Your Goal?",
                    detail: "You've been averaging \(avg14)ml — well above your \(dailyGoalMl)ml goal. Consider raising it to \(suggested)ml.",
                    icon: "arrow.up.square.fill",
                    priority: .medium
                ))
            } else if ratio < HydrationTrackerConstants.goalLowerSuggestionFraction {
                let suggested = Int(Double(dailyGoalMl) * 0.7 / 50) * 50
                insights.append(InsightItem(
                    title: "Try a Smaller Goal",
                    detail: "You're averaging \(avg14)ml vs your \(dailyGoalMl)ml goal. An intermediate goal of \(suggested)ml may be more achievable.",
                    icon: "arrow.down.square.fill",
                    priority: .medium
                ))
            }
        }

        // 9. Morning hydration check
        let morningMl = morningAverageMl()
        if morningMl < 200 && !entries.isEmpty {
            insights.append(InsightItem(
                title: "Morning Hydration",
                detail: "You averaged only \(morningMl)ml before noon. Starting earlier gives your body a head start.",
                icon: "sunrise.fill",
                priority: .medium
            ))
        }

        // 10. Personal best notification
        if let best = bestDayRecord {
            let todayTotal = todayTotalMl
            if todayTotal > 0 && todayTotal >= best.amount {
                insights.append(InsightItem(
                    title: "Personal Best!",
                    detail: "Today's intake (\(todayTotal)ml) is your highest ever. Amazing work!",
                    icon: "trophy.fill",
                    priority: .high
                ))
            }
        }

        return insights.sorted { $0.priority < $1.priority }
    }

    // MARK: - Insight Helpers

    private func weekdayAverageMl() -> Int {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let keys = (0..<30).compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let weekday = cal.component(.weekday, from: d)
            guard weekday >= 2 && weekday <= 6 else { return nil }
            return dayKey(for: d)
        }.filter { grouped[$0] != nil }
        guard !keys.isEmpty else { return 0 }
        return keys.reduce(0) { $0 + totalMl(for: $1, in: grouped) } / keys.count
    }

    private func weekendAverageMl() -> Int {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let keys = (0..<30).compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let weekday = cal.component(.weekday, from: d)
            guard weekday == 1 || weekday == 7 else { return nil }
            return dayKey(for: d)
        }.filter { grouped[$0] != nil }
        guard !keys.isEmpty else { return 0 }
        return keys.reduce(0) { $0 + totalMl(for: $1, in: grouped) } / keys.count
    }

    private func morningAverageMl() -> Int {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let allDayKeys = Array(grouped.keys)
        guard !allDayKeys.isEmpty else { return 0 }
        var totalMorningMl = 0
        for entry in entries {
            let hour = cal.component(.hour, from: entry.timeConsumed)
            if hour < 12 { totalMorningMl += entry.amountMl }
        }
        return totalMorningMl / allDayKeys.count
    }

    private func consistencyInsightDetail() -> String? {
        let cal = Calendar.current
        let grouped = entriesByDay()
        let keys = (0..<14).compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return dayKey(for: d)
        }.filter { grouped[$0] != nil }
        guard keys.count >= 5 else { return nil }
        let vals = keys.map { Double(totalMl(for: $0, in: grouped)) }
        let mean = vals.reduce(0, +) / Double(vals.count)
        let variance = vals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(vals.count)
        let stdDev = sqrt(variance)
        let stdDevInt = Int(stdDev)
        if stdDev < 200 {
            return "Very consistent this week — only ±\(stdDevInt)ml variation."
        } else if stdDev < 400 {
            return "Moderately consistent — ±\(stdDevInt)ml daily variation."
        } else {
            return "High daily variation (±\(stdDevInt)ml). Try to space intake more evenly."
        }
    }
}

// MARK: - Int Extension

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}