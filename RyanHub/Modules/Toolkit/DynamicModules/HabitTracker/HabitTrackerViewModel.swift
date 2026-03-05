import Foundation

@Observable
@MainActor
final class HabitTrackerViewModel {

    var entries: [HabitTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() { Task { await loadData() } }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let url = URL(string: "\(bridgeBaseURL)/modules/habitTracker/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([HabitTrackerEntry].self, from: data)
            entries = decoded.sorted { $0.date > $1.date }
            UserDefaults.standard.set(data, forKey: "dynamic_module_habitTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: HabitTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/habitTracker/data/add") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: req)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: HabitTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/habitTracker/data?id=\(entry.id)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    private var todayString: String { Date().dateOnlyString }

    private func entriesForDate(_ dateString: String) -> [HabitTrackerEntry] {
        entries.filter { $0.dateOnly == dateString }
    }

    private func dailyCompletionRate(for dateString: String, activeHabitSet: Set<String>) -> Double {
        let dayEntries = entriesForDate(dateString)
        guard !activeHabitSet.isEmpty else { return 0 }
        let completedNames = Set(dayEntries.filter { $0.completed }.map { $0.habitName })
        let loggedNames = Set(dayEntries.map { $0.habitName })
        // Active habits not logged at all don't break individual streaks but reduce overall rate
        let effectiveTotal = activeHabitSet.count
        let effectiveCompleted = completedNames.intersection(activeHabitSet).count
        return Double(effectiveCompleted) / Double(effectiveTotal)
    }

    // MARK: - Today

    var todayCompletedCount: Int {
        let todayEntries = entries.filter { $0.dateOnly == todayString }
        return Set(todayEntries.filter { $0.completed }.map { $0.habitName }).count
    }

    var todayTotalHabits: Int {
        let todayEntries = entries.filter { $0.dateOnly == todayString }
        return Set(todayEntries.map { $0.habitName }).count
    }

    var todayCompletionRate: Double {
        guard todayTotalHabits > 0 else { return 0 }
        return Double(todayCompletedCount) / Double(todayTotalHabits) * 100
    }

    // MARK: - Active Habits

    var activeHabits: [String] {
        let cutoff = Date().daysAgo(14).dateOnlyString
        let recent = entries.filter { $0.dateOnly >= cutoff }
        var freq: [String: Int] = [:]
        for e in recent { freq[e.habitName, default: 0] += 1 }
        return freq.sorted { $0.value > $1.value }.map { $0.key }
    }

    private var activeHabitSet: Set<String> { Set(activeHabits) }

    // MARK: - Streaks

    var overallStreak: Int {
        let habits = activeHabitSet
        guard !habits.isEmpty else { return 0 }
        var streak = 0
        var checkDate = Date().startOfDay
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        while true {
            let dateStr = fmt.string(from: checkDate)
            let rate = dailyCompletionRate(for: dateStr, activeHabitSet: habits)
            if rate >= 1.0 {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    var longestOverallStreak: Int {
        let habits = activeHabitSet
        guard !habits.isEmpty else { return 0 }
        guard let earliest = entries.map({ $0.dateOnly }).min(),
              let startDate = earliest.asCalendarDate else { return 0 }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        var best = 0
        var current = 0
        for i in 0...totalDays {
            let d = Calendar.current.date(byAdding: .day, value: i, to: startDate) ?? startDate
            let dateStr = fmt.string(from: d)
            let rate = dailyCompletionRate(for: dateStr, activeHabitSet: habits)
            if rate >= 1.0 {
                current += 1
                if current > best { best = current }
            } else {
                current = 0
            }
        }
        return best
    }

    var perHabitStreaks: [(habitName: String, currentStreak: Int, bestStreak: Int)] {
        activeHabits.map { habit in
            let completedDays = Set(
                entries.filter { $0.habitName == habit && $0.completed }.map { $0.dateOnly }
            )
            // Current streak
            var current = 0
            var checkDate = Date().startOfDay
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = .current
            while completedDays.contains(fmt.string(from: checkDate)) {
                current += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            // Best streak
            var best = 0
            var run = 0
            let sortedDays = completedDays.sorted()
            guard let firstStr = sortedDays.first, let firstDate = firstStr.asCalendarDate else {
                return (habit, current, best)
            }
            let lastStr = sortedDays.last ?? firstStr
            let lastDate = lastStr.asCalendarDate ?? firstDate
            let totalDays = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            for i in 0...totalDays {
                let d = Calendar.current.date(byAdding: .day, value: i, to: firstDate) ?? firstDate
                let ds = fmt.string(from: d)
                if completedDays.contains(ds) {
                    run += 1
                    if run > best { best = run }
                } else {
                    run = 0
                }
            }
            if current > best { best = current }
            return (habit, current, best)
        }
    }

    // MARK: - Weekly Metrics

    private func weekRange(weeksAgo: Int) -> (start: Date, end: Date) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2 // Monday
        let monday = cal.date(from: comps) ?? Date()
        let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: monday) ?? monday
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return (weekStart, weekEnd)
    }

    private func avgCompletionRate(from startDate: Date, to endDate: Date) -> Double {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let habits = activeHabitSet
        guard !habits.isEmpty else { return 0 }
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        var total = 0.0
        var count = 0
        for i in 0...totalDays {
            let d = Calendar.current.date(byAdding: .day, value: i, to: startDate) ?? startDate
            if d > Date() { continue }
            let ds = fmt.string(from: d)
            let dayEntries = entriesForDate(ds)
            if dayEntries.isEmpty { continue }
            total += dailyCompletionRate(for: ds, activeHabitSet: habits)
            count += 1
        }
        guard count > 0 else { return 0 }
        return (total / Double(count)) * 100
    }

    var weeklyCompletionRate: Double {
        let (start, end) = weekRange(weeksAgo: 0)
        return avgCompletionRate(from: start, to: end)
    }

    var previousWeekCompletionRate: Double {
        let (start, end) = weekRange(weeksAgo: 1)
        return avgCompletionRate(from: start, to: end)
    }

    var weeklyTrend: String {
        let current = weeklyCompletionRate
        let previous = previousWeekCompletionRate
        let delta = current - previous
        let sign = delta >= 0 ? "+" : ""
        if delta > 5 { return "improving (\(sign)\(Int(delta))%)" }
        if delta < -5 { return "declining (\(sign)\(Int(delta))%)" }
        return "stable (\(sign)\(Int(delta))%)"
    }

    // MARK: - Day of Week

    var completionRateByDayOfWeek: [(day: String, rate: Double)] {
        let habits = activeHabitSet
        guard !habits.isEmpty else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        var dayRates: [Int: [Double]] = [:]
        for i in 0..<28 {
            let d = Date().daysAgo(i)
            let ds = fmt.string(from: d)
            let dayEntries = entriesForDate(ds)
            if dayEntries.isEmpty { continue }
            let rate = dailyCompletionRate(for: ds, activeHabitSet: habits)
            let weekday = d.weekdayIndex
            dayRates[weekday, default: []].append(rate)
        }
        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon–Sun
        let dayNames = [2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat", 1: "Sun"]
        return orderedWeekdays.compactMap { idx -> (day: String, rate: Double)? in
            guard let name = dayNames[idx], let rates = dayRates[idx], !rates.isEmpty else { return nil }
            return (name, rates.reduce(0, +) / Double(rates.count))
        }
    }

    // MARK: - Per-Habit Consistency

    private func habitCompletionRate(_ habit: String, days: Int) -> (rate: Double, count: Int) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        var completed = 0
        var total = 0
        for i in 0..<days {
            let ds = fmt.string(from: Date().daysAgo(i))
            let dayEntries = entries.filter { $0.dateOnly == ds && $0.habitName == habit }
            if dayEntries.isEmpty { continue }
            total += 1
            if dayEntries.contains(where: { $0.completed }) { completed += 1 }
        }
        guard total > 0 else { return (0, 0) }
        return (Double(completed) / Double(total), total)
    }

    var mostConsistentHabit: String? {
        let candidates = activeHabits.compactMap { habit -> (String, Double)? in
            let (rate, count) = habitCompletionRate(habit, days: 30)
            guard count >= 7 else { return nil }
            return (habit, rate)
        }
        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    var leastConsistentHabit: String? {
        let candidates = activeHabits.compactMap { habit -> (String, Double)? in
            let (rate, count) = habitCompletionRate(habit, days: 30)
            guard count >= 7 else { return nil }
            return (habit, rate)
        }
        return candidates.min(by: { $0.1 < $1.1 })?.0
    }

    // MARK: - Category Breakdown

    var categoryBreakdown: [(category: String, count: Int, completionRate: Double)] {
        var grouped: [HabitCategory: [HabitTrackerEntry]] = [:]
        for e in entries { grouped[e.category, default: []].append(e) }
        return grouped.map { cat, items in
            let completed = items.filter { $0.completed }.count
            let rate = items.isEmpty ? 0 : Double(completed) / Double(items.count)
            return (cat.displayName, items.count, rate)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - Chart Data

    var weeklyChartData: [(date: Date, rate: Double)] {
        let habits = activeHabitSet
        guard !habits.isEmpty else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return (0..<56).compactMap { i -> (Date, Double)? in
            let d = Date().daysAgo(55 - i)
            let ds = fmt.string(from: d)
            let dayEntries = entriesForDate(ds)
            if dayEntries.isEmpty { return nil }
            let rate = dailyCompletionRate(for: ds, activeHabitSet: habits)
            return (d, rate)
        }
    }

    var perHabitChartData: [(habitName: String, rate: Double)] {
        activeHabits.map { habit in
            let (rate, _) = habitCompletionRate(habit, days: 30)
            return (habit, rate)
        }.sorted { $0.rate > $1.rate }
    }

    var heatmapData: [(date: Date, intensity: Double)] {
        let habits = activeHabitSet
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return (0..<90).map { i -> (Date, Double) in
            let d = Date().daysAgo(89 - i)
            let ds = fmt.string(from: d)
            let dayEntries = entriesForDate(ds)
            if dayEntries.isEmpty || habits.isEmpty { return (d, 0) }
            return (d, dailyCompletionRate(for: ds, activeHabitSet: habits))
        }
    }

    // MARK: - Duration

    var averageDailyDuration: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        var dailyTotals: [Int] = []
        for i in 0..<7 {
            let ds = fmt.string(from: Date().daysAgo(i))
            let total = entries.filter { $0.dateOnly == ds }.reduce(0) { $0 + $1.durationMinutes }
            if entries.contains(where: { $0.dateOnly == ds }) {
                dailyTotals.append(total)
            }
        }
        guard !dailyTotals.isEmpty else { return 0 }
        return dailyTotals.reduce(0, +) / dailyTotals.count
    }

    var totalCompletionsAllTime: Int {
        entries.filter { $0.completed }.count
    }

    /// Alias used by AnalyticsView.
    var totalCompletions: Int { totalCompletionsAllTime }

    /// Overall completion rate across all entries (0.0–1.0).
    var overallCompletionRate: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.filter { $0.completed }.count) / Double(entries.count)
    }

    // MARK: - Streak Aliases

    /// Alias for `overallStreak`, used by dashboard and analytics views.
    var currentStreak: Int { overallStreak }

    /// Alias for `longestOverallStreak`, used by dashboard and analytics views.
    var longestStreak: Int { longestOverallStreak }

    /// Whether any habit entry has been logged today.
    var isActiveToday: Bool {
        !entries.filter { $0.dateOnly == todayString }.isEmpty
    }

    /// Today's entries, used by DashboardView.
    var todayEntries: [HabitTrackerEntry] {
        entries.filter { $0.dateOnly == todayString }
    }

    // MARK: - Streak Summaries

    /// Per-habit streak data as `HabitStreakSummary` for the analytics view.
    var streakSummaries: [HabitStreakSummary] {
        perHabitStreaks.map { s in
            HabitStreakSummary(
                habitName: s.habitName,
                currentStreak: s.currentStreak,
                bestStreak: s.bestStreak
            )
        }
    }

    // MARK: - Chart Data (for ModuleChartView)

    /// Completion trend as `[ChartDataPoint]` for `ModuleChartView`.
    var chartData: [ChartDataPoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return weeklyChartData.map { item in
            ChartDataPoint(label: fmt.string(from: item.date), value: item.rate * 100)
        }
    }

    // MARK: - Heatmap Data (dictionary for CalendarHeatmap)

    /// Heatmap data as `[Date: Double]` keyed by start-of-day, for `CalendarHeatmap`.
    var heatmapDataDictionary: [Date: Double] {
        var dict: [Date: Double] = [:]
        for item in heatmapData {
            let key = Calendar.current.startOfDay(for: item.date)
            dict[key] = item.intensity
        }
        return dict
    }

    // MARK: - Category Breakdowns (for analytics view)

    /// Category data as `[HabitCategoryBreakdown]` for the analytics view.
    var categoryBreakdowns: [HabitCategoryBreakdown] {
        var grouped: [HabitCategory: [HabitTrackerEntry]] = [:]
        for e in entries { grouped[e.category, default: []].append(e) }
        return grouped.map { cat, items in
            let completed = items.filter { $0.completed }.count
            let rate = items.isEmpty ? 0 : Double(completed) / Double(items.count)
            return HabitCategoryBreakdown(
                categoryName: cat.displayName,
                category: cat,
                count: items.count,
                completionRate: rate
            )
        }.sorted { $0.count > $1.count }
    }

    // MARK: - Day-of-Week Stats (for analytics view)

    /// Day-of-week completion data as `[DayOfWeekStat]` for the analytics view.
    var dayOfWeekStats: [DayOfWeekStat] {
        completionRateByDayOfWeek.map { item in
            DayOfWeekStat(day: item.day, rate: item.rate)
        }
    }

    // MARK: - Module Insights (for InsightsList)

    /// Insights as `[ModuleInsight]` for `InsightsList`.
    var moduleInsights: [ModuleInsight] {
        insights.map { text in
            let type = classifyInsight(text)
            let (title, message) = splitInsight(text)
            return ModuleInsight(type: type, title: title, message: message)
        }
    }

    private func classifyInsight(_ text: String) -> InsightType {
        if text.hasPrefix("📈") || text.hasPrefix("📉") || text.hasPrefix("📅") || text.hasPrefix("⏱️") {
            return .trend
        } else if text.hasPrefix("🔥") || text.hasPrefix("⭐") || text.hasPrefix("✅") || text.hasPrefix("👋") {
            return .achievement
        } else if text.hasPrefix("🎯") || text.hasPrefix("💪") {
            return .suggestion
        } else if text.hasPrefix("⚠️") {
            return .warning
        }
        return .suggestion
    }

    private func splitInsight(_ text: String) -> (String, String) {
        // Strip leading emoji + space
        var stripped = text
        if let first = text.unicodeScalars.first, !first.isASCII {
            stripped = String(text.drop(while: { !$0.isASCII || $0 == " " }).dropFirst(0))
            // Drop emoji and whitespace prefix
            let idx = text.index(text.startIndex, offsetBy: text.distance(from: text.startIndex, to: text.firstIndex(of: " ") ?? text.startIndex) + 1, limitedBy: text.endIndex) ?? text.startIndex
            stripped = String(text[idx...])
        }
        // Split at first period or dash
        if let dotIndex = stripped.firstIndex(of: "!") {
            let title = String(stripped[stripped.startIndex...dotIndex])
            let rest = String(stripped[stripped.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
            return (title, rest.isEmpty ? stripped : rest)
        }
        if let dotIndex = stripped.firstIndex(of: ".") {
            let title = String(stripped[stripped.startIndex...dotIndex])
            let rest = String(stripped[stripped.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
            return (title, rest.isEmpty ? stripped : rest)
        }
        return (stripped, "")
    }

    // MARK: - Insights

    var insights: [String] {
        var result: [String] = []

        // Streak milestones
        let streak = overallStreak
        let milestones = [7, 14, 21, 30, 50, 100]
        if milestones.contains(streak) {
            result.append("🔥 \(streak)-day streak! You've completed all habits for \(streak) days straight — that's a milestone!")
        }

        // Per-habit streak milestones
        for s in perHabitStreaks {
            let isPB = s.currentStreak > 0 && s.currentStreak == s.bestStreak
            if milestones.contains(s.currentStreak) && isPB {
                result.append("⭐ \(s.habitName): \(s.currentStreak)-day streak — a new personal best!")
            }
        }

        // Most consistent habit
        if let best = mostConsistentHabit {
            let (rate, _) = habitCompletionRate(best, days: 30)
            result.append("✅ \(best) is your most consistent habit at \(Int(rate * 100))% completion rate over 30 days.")
        }

        // Least consistent habit nudge
        if let worst = leastConsistentHabit {
            let (rate30, _) = habitCompletionRate(worst, days: 30)
            let (rate7, _) = habitCompletionRate(worst, days: 7)
            if rate7 < rate30 - 0.2 {
                result.append("⚠️ \(worst) dropped to \(Int(rate7 * 100))% this week — down from \(Int(rate30 * 100))% over 30 days. Time to refocus?")
            } else {
                result.append("💪 \(worst) could use some attention at \(Int(rate30 * 100))% over 30 days.")
            }
        }

        // Day-of-week pattern
        let dowRates = completionRateByDayOfWeek
        if let bestDay = dowRates.max(by: { $0.rate < $1.rate }),
           let worstDay = dowRates.min(by: { $0.rate < $1.rate }),
           bestDay.rate - worstDay.rate > 0.2 {
            result.append("📅 You complete \(Int((bestDay.rate - worstDay.rate) * 100))% more habits on \(bestDay.day)s than \(worstDay.day)s — consider lighter \(worstDay.day) goals.")
        }

        // Week-over-week trend
        let currentRate = weeklyCompletionRate
        let previousRate = previousWeekCompletionRate
        let delta = currentRate - previousRate
        if delta > 5 {
            result.append("📈 Great week! Your completion rate improved from \(Int(previousRate))% to \(Int(currentRate))%.")
        } else if delta < -5 {
            result.append("📉 Your completion rate dipped from \(Int(previousRate))% to \(Int(currentRate))% this week. Stay consistent!")
        }

        // Category balance
        let categories = Set(entries.map { $0.category })
        if categories.count == 1, let only = categories.first {
            let others = HabitCategory.allCases.filter { $0 != only }.prefix(2).map { $0.displayName }
            result.append("🎯 All your habits are \(only.displayName)-related. Consider adding \(others.joined(separator: " or ")) habits for balance.")
        }

        // Duration insight
        let avg7 = averageDailyDuration
        let avg30: Int = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = .current
            var totals: [Int] = []
            for i in 0..<30 {
                let ds = fmt.string(from: Date().daysAgo(i))
                let total = entries.filter { $0.dateOnly == ds }.reduce(0) { $0 + $1.durationMinutes }
                if entries.contains(where: { $0.dateOnly == ds }) { totals.append(total) }
            }
            guard !totals.isEmpty else { return 0 }
            return totals.reduce(0, +) / totals.count
        }()
        if avg7 > 0 {
            let diff = avg7 - avg30
            let diffStr = diff >= 0 ? "up \(diff)" : "down \(abs(diff))"
            result.append("⏱️ You spend ~\(avg7) min/day on habits — \(diffStr) min vs. last month.")
        }

        // Comeback detection
        let recentDays = (0..<7).map { Date().daysAgo($0).dateOnlyString }
        let loggedDays = Set(entries.map { $0.dateOnly })
        let gapStart = recentDays.first(where: { !loggedDays.contains($0) })
        if let gap = gapStart, let gapDate = gap.asCalendarDate {
            let gapLength = Calendar.current.dateComponents([.day], from: gapDate, to: Date()).day ?? 0
            if gapLength >= 2 && loggedDays.contains(todayString) {
                result.append("👋 Welcome back! You logged habits after a \(gapLength)-day gap. Keep the momentum going!")
            }
        }

        return result
    }
}

// Note: isPersonalBest is defined directly in HabitStreakSummary (HabitTrackerModels.swift)