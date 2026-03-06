import Foundation

// MARK: - HydrationTrackerViewModel

@Observable
@MainActor
final class HydrationTrackerViewModel {

    // MARK: - State

    var entries: [HydrationTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var selectedDrinkType: DrinkType = .water
    var isShowingCustomEntry = false
    var isEditingGoal = false
    var editingGoalValue: Int = HydrationTrackerKeys.defaultDailyGoal

    // MARK: - Bridge Server

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    private let moduleId = "hydrationTracker"

    // MARK: - Init

    init() {
        editingGoalValue = dailyGoal
        Task { await loadData() }
    }

    // MARK: - Daily Goal (UserDefaults-backed)

    var dailyGoal: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: HydrationTrackerKeys.dailyGoal)
            return stored > 0 ? stored : HydrationTrackerKeys.defaultDailyGoal
        }
        set {
            let clamped = max(500, min(5000, newValue))
            UserDefaults.standard.set(clamped, forKey: HydrationTrackerKeys.dailyGoal)
        }
    }

    // MARK: - Today Computed Properties

    var todayIntake: Int {
        todayEntries.reduce(0) { $0 + $1.amount }
    }

    var goalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return Double(todayIntake) / Double(dailyGoal)
    }

    var goalReached: Bool {
        todayIntake >= dailyGoal
    }

    var remainingMl: Int {
        max(0, dailyGoal - todayIntake)
    }

    var todayEntries: [HydrationTrackerEntry] {
        entries
            .filter { $0.isToday }
            .sorted { a, b in
                guard let da = a.parsedDate, let db = b.parsedDate else { return false }
                return da > db
            }
    }

    // MARK: - Streak

    var currentStreak: Int {
        let cal = Calendar.current
        let goal = dailyGoal
        let dailyTotals = buildDailyTotals()

        var streak = 0
        var checkDate = Date()

        // If today hasn't met goal yet, start checking from yesterday
        let todayKey = calendarDayString(for: checkDate)
        let todayTotal = dailyTotals[todayKey] ?? 0
        if todayTotal < goal {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        for i in 0..<365 {
            guard let day = cal.date(byAdding: .day, value: -i, to: checkDate) else { break }
            let key = calendarDayString(for: day)
            let total = dailyTotals[key] ?? 0
            if total >= goal {
                streak += 1
            } else {
                break
            }
        }

        // Update best streak
        let bestStreak = UserDefaults.standard.integer(forKey: HydrationTrackerKeys.bestStreak)
        if streak > bestStreak {
            UserDefaults.standard.set(streak, forKey: HydrationTrackerKeys.bestStreak)
        }

        return streak
    }

    var bestStreak: Int {
        let stored = UserDefaults.standard.integer(forKey: HydrationTrackerKeys.bestStreak)
        return max(stored, currentStreak)
    }

    // MARK: - Weekly Data

    var weeklyData: [(date: Date, total: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dailyTotals = buildDailyTotals()

        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = calendarDayString(for: day)
            let total = dailyTotals[key] ?? 0
            return (date: day, total: total)
        }
    }

    var weeklyAverage: Int {
        let totals = weeklyData.map(\.total)
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / 7
    }

    // MARK: - Trend Analysis

    var weeklyTrendPercentage: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dailyTotals = buildDailyTotals()

        let currentWeekTotal = (0..<7).reduce(0) { acc, offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return acc }
            return acc + (dailyTotals[calendarDayString(for: day)] ?? 0)
        }

        let previousWeekTotal = (7..<14).reduce(0) { acc, offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return acc }
            return acc + (dailyTotals[calendarDayString(for: day)] ?? 0)
        }

        guard previousWeekTotal > 0 else { return 0 }
        let previousAvg = Double(previousWeekTotal) / 7.0
        let currentAvg = Double(currentWeekTotal) / 7.0
        return ((currentAvg - previousAvg) / previousAvg) * 100
    }

    var isTrendingUp: Bool {
        weeklyTrendPercentage > 0
    }

    // MARK: - Goal Completion Rate (last 30 days)

    var goalCompletionRate: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dailyTotals = buildDailyTotals()
        let goal = dailyGoal

        var daysWithEntries = 0
        var daysMeetingGoal = 0

        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = calendarDayString(for: day)
            if let total = dailyTotals[key], total > 0 {
                daysWithEntries += 1
                if total >= goal {
                    daysMeetingGoal += 1
                }
            }
        }

        guard daysWithEntries > 0 else { return 0 }
        return Double(daysMeetingGoal) / Double(daysWithEntries) * 100
    }

    // MARK: - Peak Hydration Period

    var peakHydrationPeriod: HydrationTimePeriod? {
        let periodCounts = Dictionary(grouping: entries) { entry -> HydrationTimePeriod in
            guard let date = entry.parsedDate else { return .morning }
            let hour = Calendar.current.component(.hour, from: date)
            return HydrationTimePeriod.from(hour: hour)
        }
        .mapValues { $0.count }

        return periodCounts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Drink Type Breakdown (weekly)

    var drinkTypeBreakdown: [DrinkTypeBreakdown] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today) ?? today

        let weekEntries = entries.filter { entry in
            guard let date = entry.parsedDate else { return false }
            return date >= weekAgo
        }

        let totalMl = weekEntries.reduce(0) { $0 + $1.amount }
        guard totalMl > 0 else { return [] }

        let grouped = Dictionary(grouping: weekEntries, by: \.drinkType)
        return grouped.map { type, typeEntries in
            let typeTotalMl = typeEntries.reduce(0) { $0 + $1.amount }
            let percentage = Double(typeTotalMl) / Double(totalMl) * 100
            return DrinkTypeBreakdown(drinkType: type, totalMl: typeTotalMl, percentage: percentage)
        }
        .sorted { $0.totalMl > $1.totalMl }
    }

    // MARK: - Chart Data

    var chartData: [ChartDataPoint] {
        weeklyData.map { item in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            let label = formatter.string(from: item.date)
            return ChartDataPoint(label: label, value: Double(item.total))
        }
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Goal completion rate
        let rate = goalCompletionRate
        if rate > 0 {
            let rateStr = String(format: "%.0f%%", rate)
            if rate >= 80 {
                result.append(ModuleInsight(
                    type: .achievement,
                    title: "Strong Consistency",
                    message: "You've met your hydration goal \(rateStr) of tracked days this month."
                ))
            } else if rate < 50 {
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Room to Improve",
                    message: "You've met your goal only \(rateStr) of tracked days. Try setting reminders."
                ))
            }
        }

        // Best streak
        let best = bestStreak
        if best > 0 {
            if currentStreak == best && currentStreak > 1 {
                result.append(ModuleInsight(
                    type: .achievement,
                    title: "New Record!",
                    message: "You're on your longest streak ever — \(best) days!"
                ))
            } else if best > 1 {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Best Streak",
                    message: "Your longest streak is \(best) days. Current: \(currentStreak) days."
                ))
            }
        }

        // Weekly trend
        let trend = weeklyTrendPercentage
        if abs(trend) > 5 {
            let direction = trend > 0 ? "up" : "down"
            let pct = String(format: "%.0f%%", abs(trend))
            result.append(ModuleInsight(
                type: .trend,
                title: "Weekly Trend",
                message: "Your average intake is \(direction) \(pct) compared to last week."
            ))
        }

        // Peak hydration period
        if let peak = peakHydrationPeriod {
            result.append(ModuleInsight(
                type: .trend,
                title: "Peak Hydration Time",
                message: "You drink most often in the \(peak.displayName.lowercased())."
            ))
        }

        // Low intake warning
        if todayIntake > 0 && !goalReached {
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 18 {
                result.append(ModuleInsight(
                    type: .warning,
                    title: "Evening Reminder",
                    message: "You still need \(remainingMl)ml to reach today's goal."
                ))
            }
        }

        return result
    }

    // MARK: - Weekly Summaries (for charts/analytics views)

    var weeklySummaries: [HydrationDaySummary] {
        weeklyData.map { item in
            HydrationDaySummary(date: item.date, total: item.total, dailyGoal: dailyGoal)
        }
    }

    // MARK: - CRUD Operations

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data") else {
                errorMessage = "Invalid URL"
                return
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Server error"
                return
            }
            let decoder = JSONDecoder()
            entries = try decoder.decode([HydrationTrackerEntry].self, from: data)
            cacheData()
        } catch {
            errorMessage = error.localizedDescription
            loadFromCache()
        }
    }

    func addEntry(_ entry: HydrationTrackerEntry) async {
        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data/add") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                entries.append(entry)
                cacheData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: HydrationTrackerEntry) async {
        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data?id=\(entry.id)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                entries.removeAll { $0.id == entry.id }
                cacheData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Quick Add

    func quickAdd(preset: HydrationPreset) async {
        var entry = HydrationTrackerEntry()
        entry.amount = preset.amount
        entry.drinkType = selectedDrinkType
        await addEntry(entry)
    }

    func quickAddAmount(_ amount: Int, drinkType: DrinkType) async {
        var entry = HydrationTrackerEntry()
        entry.amount = amount
        entry.drinkType = drinkType
        await addEntry(entry)
    }

    // MARK: - Goal Editing

    func updateDailyGoal(_ newGoal: Int) {
        dailyGoal = newGoal
        editingGoalValue = dailyGoal
    }

    // MARK: - Helpers

    private func buildDailyTotals() -> [String: Int] {
        var totals: [String: Int] = [:]
        for entry in entries {
            let key = entry.calendarDay
            totals[key, default: 0] += entry.amount
        }
        return totals
    }

    private func calendarDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func cacheData() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "dynamic_module_\(moduleId)_cache")
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_\(moduleId)_cache"),
              let cached = try? JSONDecoder().decode([HydrationTrackerEntry].self, from: data) else { return }
        entries = cached
    }
}