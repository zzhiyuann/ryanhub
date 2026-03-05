import Foundation

@Observable
@MainActor
final class SpendingTrackerViewModel {

    // MARK: - State

    var entries: [SpendingTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyBudgetGoal: Double = 50.0

    // MARK: - Bridge URL

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    // MARK: - Init

    init() {
        dailyBudgetGoal = UserDefaults.standard.double(forKey: "spendingTracker_dailyBudget").nonZero ?? 50.0
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/spendingTracker/data") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([SpendingTrackerEntry].self, from: data)
            entries = decoded.sorted { $0.parsedDate > $1.parsedDate }
            UserDefaults.standard.set(data, forKey: "dynamic_module_spendingTracker_cache")
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }

    func addEntry(_ entry: SpendingTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/spendingTracker/data/add") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = "Failed to add entry: \(error.localizedDescription)"
        }
    }

    func deleteEntry(_ entry: SpendingTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/spendingTracker/data?id=\(entry.id)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
        }
    }

    func saveBudgetGoal(_ goal: Double) {
        dailyBudgetGoal = goal
        UserDefaults.standard.set(goal, forKey: "spendingTracker_dailyBudget")
    }

    // MARK: - Date Helpers

    private var calendar: Calendar { Calendar.current }

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var currentWeekStart: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Monday = 1 in our system; calendar.firstWeekday may differ
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }

    private var currentMonthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: comps) ?? Date()
    }

    // MARK: - Today

    var todayEntries: [SpendingTrackerEntry] {
        entries
            .filter { calendar.isDateInToday($0.parsedDate) }
            .sorted { $0.parsedDate > $1.parsedDate }
    }

    var todayTotal: Double {
        todayEntries.reduce(0) { $0 + $1.amount }
    }

    var todayBudgetProgress: Double {
        guard dailyBudgetGoal > 0 else { return 1.0 }
        return min(todayTotal / dailyBudgetGoal, 1.0)
    }

    var todayBudgetState: BudgetProgressState {
        BudgetProgressState(progress: todayBudgetProgress)
    }

    // MARK: - Weekly

    var weeklyTotal: Double {
        let weekStart = currentWeekStart
        return entries
            .filter { $0.parsedDate >= weekStart }
            .reduce(0) { $0 + $1.amount }
    }

    var weeklyAverage: Double {
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        let recent = entries.filter { $0.parsedDate >= sevenDaysAgo }
        let total = recent.reduce(0) { $0 + $1.amount }
        return total / 7.0
    }

    // MARK: - Monthly

    var monthlyTotal: Double {
        entries
            .filter { $0.parsedDate >= currentMonthStart }
            .reduce(0) { $0 + $1.amount }
    }

    var recurringTotal: Double {
        entries
            .filter { $0.parsedDate >= currentMonthStart && $0.isRecurring }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Budget Streak

    var underBudgetStreak: Int {
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        // Look back up to 365 days
        for _ in 0..<365 {
            let dayTotal = entries
                .filter { calendar.isDate($0.parsedDate, inSameDayAs: checkDate) }
                .reduce(0) { $0 + $1.amount }

            if dayTotal <= dailyBudgetGoal {
                streak += 1
            } else {
                break
            }

            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        return streak
    }

    // MARK: - Category Breakdown

    var categoryBreakdown: [(SpendingCategory, Double)] {
        let monthEntries = entries.filter { $0.parsedDate >= currentMonthStart }
        var totals: [SpendingCategory: Double] = [:]
        for entry in monthEntries {
            totals[entry.category, default: 0] += entry.amount
        }
        return totals
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    var topCategory: SpendingCategory? {
        categoryBreakdown.first?.0
    }

    // MARK: - Chart Data

    var dailyTrendData: [(Date, Double)] {
        let now = Date()
        return (0..<30).compactMap { offset -> (Date, Double)? in
            guard let day = calendar.date(byAdding: .day, value: -(29 - offset), to: calendar.startOfDay(for: now)) else { return nil }
            let total = entries
                .filter { calendar.isDate($0.parsedDate, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return (day, total)
        }
    }

    var chartData: [ChartDataPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return dailyTrendData.map { (date, total) in
            ChartDataPoint(label: formatter.string(from: date), value: total)
        }
    }

    var categoryChartData: [ChartDataPoint] {
        categoryBreakdown.map { (category, total) in
            ChartDataPoint(label: category.displayName, value: total)
        }
    }

    // MARK: - Day-of-Week Averages

    var dayOfWeekAverages: [(String, Double)] {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat — map to Mon=0...Sun=6
        var dayTotals: [Int: Double] = [:]
        var dayCounts: [Int: Int] = [:]

        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.parsedDate)
            let index = (weekday + 5) % 7 // Mon=0, ..., Sun=6
            dayTotals[index, default: 0] += entry.amount
            dayCounts[index, default: 0] += 1
        }

        // Compute average per weekday using unique day counts
        var dayUniqueCounts: [Int: Set<String>] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.parsedDate)
            let index = (weekday + 5) % 7
            let key = dateFormatter.string(from: entry.parsedDate)
            dayUniqueCounts[index, default: []].insert(key)
        }

        return dayNames.enumerated().map { (index, name) in
            let total = dayTotals[index] ?? 0
            let uniqueDays = dayUniqueCounts[index]?.count ?? 0
            let average = uniqueDays > 0 ? total / Double(uniqueDays) : 0
            return (name, average)
        }
    }

    var busiestDayOfWeek: String? {
        dayOfWeekAverages.max(by: { $0.1 < $1.1 }).map { $0.0 }
    }

    // MARK: - Week-over-Week Change

    var weekOverWeekChange: Double {
        let now = Date()
        let thisWeekStart = currentWeekStart
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart

        let thisWeekTotal = entries
            .filter { $0.parsedDate >= thisWeekStart }
            .reduce(0) { $0 + $1.amount }

        let lastWeekTotal = entries
            .filter { $0.parsedDate >= lastWeekStart && $0.parsedDate < thisWeekStart }
            .reduce(0) { $0 + $1.amount }

        guard lastWeekTotal > 0 else { return 0 }
        return (thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100.0
    }

    // MARK: - Spending-Free Days

    var spendingFreeDays: Int {
        let monthStart = currentMonthStart
        let today = calendar.startOfDay(for: Date())

        guard let daysInMonth = calendar.dateComponents([.day], from: monthStart, to: today).day else { return 0 }

        var freeDays = 0
        for offset in 0..<daysInMonth {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monthStart) else { continue }
            let hasSpending = entries.contains { calendar.isDate($0.parsedDate, inSameDayAs: day) }
            if !hasSpending { freeDays += 1 }
        }
        return freeDays
    }

    // MARK: - Budget Pace

    private var projectedMonthEnd: Double {
        let monthStart = currentMonthStart
        let now = Date()
        guard let daysElapsed = calendar.dateComponents([.day], from: monthStart, to: now).day,
              daysElapsed > 0 else { return monthlyTotal }

        guard let totalDays = calendar.range(of: .day, in: .month, for: now)?.count else { return monthlyTotal }
        return (monthlyTotal / Double(daysElapsed)) * Double(totalDays)
    }

    // MARK: - Category Spike Detection

    private func categorySpike() -> (SpendingCategory, Double)? {
        let thisWeekStart = currentWeekStart

        for category in SpendingCategory.allCases {
            let thisWeekTotal = entries
                .filter { $0.parsedDate >= thisWeekStart && $0.category == category }
                .reduce(0) { $0 + $1.amount }

            guard thisWeekTotal > 0 else { continue }

            // 4-week average (excluding this week)
            var weeklyTotals: [Double] = []
            for weekOffset in 1...4 {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: thisWeekStart),
                      let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { continue }
                let wTotal = entries
                    .filter { $0.parsedDate >= weekStart && $0.parsedDate < weekEnd && $0.category == category }
                    .reduce(0) { $0 + $1.amount }
                weeklyTotals.append(wTotal)
            }

            let pastAvg = weeklyTotals.isEmpty ? 0 : weeklyTotals.reduce(0, +) / Double(weeklyTotals.count)
            if pastAvg > 0 && thisWeekTotal > pastAvg * 1.3 {
                let percentIncrease = (thisWeekTotal - pastAvg) / pastAvg * 100
                return (category, percentIncrease)
            }
        }
        return nil
    }

    // MARK: - Insights

    var insights: [String] {
        var result: [String] = []

        // 1. Week-over-week change
        let wow = weekOverWeekChange
        if abs(wow) >= 5 {
            if wow > 0 {
                result.append(String(format: "You spent %.0f%% more this week vs last week.", wow))
            } else {
                result.append(String(format: "Nice! You spent %.0f%% less this week vs last week.", abs(wow)))
            }
        }

        // 2. Category spike
        if let (spikeCategory, pct) = categorySpike() {
            result.append(String(format: "%@ is up %.0f%% vs your 4-week average — worth a look.", spikeCategory.displayName, pct))
        }

        // 3. Under-budget streak
        let streak = underBudgetStreak
        if streak >= 3 {
            result.append(String(format: "Amazing! %d-day streak of staying under $%.0f/day 🎉", streak, dailyBudgetGoal))
        }

        // 4. Spending-free days
        let freeDays = spendingFreeDays
        if freeDays > 0 {
            result.append(String(format: "You had %d no-spend day%@ this month — nice discipline!", freeDays, freeDays == 1 ? "" : "s"))
        }

        // 5. Top category
        if let top = topCategory, monthlyTotal > 0 {
            let topAmount = categoryBreakdown.first?.1 ?? 0
            let pct = topAmount / monthlyTotal * 100
            result.append(String(format: "%@ accounts for %.0f%% of your monthly spending.", top.displayName, pct))
        }

        // 6. Day-of-week pattern
        if let busiest = busiestDayOfWeek {
            let avg = dayOfWeekAverages.first(where: { $0.0 == busiest })?.1 ?? 0
            if avg > 0 {
                result.append(String(format: "%@s average $%.0f — your most expensive day.", busiest, avg))
            }
        }

        // 7. Recurring vs discretionary
        if monthlyTotal > 0 && recurringTotal > 0 {
            let pct = recurringTotal / monthlyTotal * 100
            result.append(String(format: "Fixed expenses are $%.0f (%.0f%% of monthly total).", recurringTotal, pct))
        }

        // 8. Budget pace
        let projected = projectedMonthEnd
        let monthlyBudget = dailyBudgetGoal * 30
        if projected > monthlyBudget * 1.05 {
            result.append(String(format: "At this pace, you'll spend $%.0f by month end (budget: $%.0f).", projected, monthlyBudget))
        }

        return Array(result.prefix(4))
    }

    // MARK: - Module Insights (for InsightCard)

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Streak achievement
        let streak = underBudgetStreak
        if streak >= 3 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(streak)-Day Under-Budget Streak",
                message: "You've stayed within $\(Int(dailyBudgetGoal))/day for \(streak) days in a row."
            ))
        }

        // Category spike warning
        if let (spikeCategory, pct) = categorySpike() {
            result.append(ModuleInsight(
                type: .warning,
                title: "\(spikeCategory.displayName) Up \(Int(pct))%",
                message: "\(spikeCategory.displayName) spending this week is well above your 4-week average."
            ))
        }

        // Week-over-week trend
        let wow = weekOverWeekChange
        if abs(wow) >= 5 {
            let direction = wow > 0 ? "up" : "down"
            result.append(ModuleInsight(
                type: wow > 0 ? .trend : .achievement,
                title: "Weekly Spending \(wow > 0 ? "Increased" : "Decreased")",
                message: String(format: "Your weekly total is %@ %.0f%% vs last week.", direction, abs(wow))
            ))
        }

        // Suggestion: budget pace
        let projected = projectedMonthEnd
        let monthlyBudget = dailyBudgetGoal * 30
        if projected > monthlyBudget * 1.1 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "On Track to Overspend",
                message: String(format: "Projected month-end total: $%.0f. Consider reducing daily spending.", projected)
            ))
        }

        // No-spend days
        let freeDays = spendingFreeDays
        if freeDays >= 2 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(freeDays) No-Spend Days",
                message: "Great discipline — you had \(freeDays) spending-free days this month!"
            ))
        }

        return Array(result.prefix(3))
    }

    // MARK: - Day Summaries (for history grouped view)

    var daySummaries: [SpendingDaySummary] {
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            calendar.startOfDay(for: entry.parsedDate)
        }
        return grouped
            .map { SpendingDaySummary(date: $0.key, entries: $0.value, dailyBudget: dailyBudgetGoal) }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Double Helper

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}