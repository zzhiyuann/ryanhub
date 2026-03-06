import Foundation

// MARK: - SpendingTrackerViewModel

@Observable
@MainActor
final class SpendingTrackerViewModel {

    // MARK: - State

    var entries: [SpendingTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

    // Navigation — tabbedSegmented
    var selectedTab: SpendingTab = .today

    // Entry sheet state — fab+sheet
    var showingEntrySheet = false
    var entryAmount: String = ""
    var entryCategory: SpendingCategory = .other
    var entryNote: String = ""

    // Breakdown month picker
    var selectedMonthOffset: Int = 0 // 0 = current month, -1 = last month, etc.

    // Budget
    var dailyBudget: Double {
        get { UserDefaults.standard.double(forKey: "spendingTracker_dailyBudget").nonZero ?? 50.0 }
        set { UserDefaults.standard.set(newValue, forKey: "spendingTracker_dailyBudget") }
    }

    // MARK: - Tab Enum

    enum SpendingTab: String, CaseIterable, Identifiable {
        case today = "Today"
        case breakdown = "Breakdown"
        case trends = "Trends"

        var id: String { rawValue }
    }

    // MARK: - Bridge Server

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    private let moduleId = "spendingTracker"

    // MARK: - Init

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data") else {
            errorMessage = "Invalid URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            entries = try decoder.decode([SpendingTrackerEntry].self, from: data)
            cacheData()
        } catch {
            errorMessage = error.localizedDescription
            // Load from cache as fallback
            loadFromCache()
        }
    }

    func addEntry(_ entry: SpendingTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data/add") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: SpendingTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data?id=\(entry.id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Quick Add from Sheet

    func saveEntryFromSheet() async {
        guard let amount = Double(entryAmount), amount > 0 else { return }

        var entry = SpendingTrackerEntry()
        entry.amount = amount
        entry.category = entryCategory
        entry.note = entryNote.trimmingCharacters(in: .whitespacesAndNewlines)

        await addEntry(entry)
        resetEntrySheet()
    }

    func resetEntrySheet() {
        entryAmount = ""
        entryCategory = .other
        entryNote = ""
        showingEntrySheet = false
    }

    // MARK: - Cache

    private func cacheData() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "dynamic_module_\(moduleId)_cache")
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_\(moduleId)_cache"),
              let cached = try? JSONDecoder().decode([SpendingTrackerEntry].self, from: data) else { return }
        entries = cached
    }

    // MARK: - Date Helpers

    private let calendar = Calendar.current

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func dayString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: dateString)
    }

    private func entriesForDay(_ dayStr: String) -> [SpendingTrackerEntry] {
        entries.filter { $0.dayString == dayStr }
    }

    private func totalForDay(_ dayStr: String) -> Double {
        entriesForDay(dayStr).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Selected Month Helpers

    private var selectedMonthDate: Date {
        calendar.date(byAdding: .month, value: selectedMonthOffset, to: Date()) ?? Date()
    }

    private var selectedMonthRange: (start: String, end: String) {
        let comps = calendar.dateComponents([.year, .month], from: selectedMonthDate)
        guard let monthStart = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return ("", "")
        }
        return (dayString(for: monthStart), dayString(for: nextMonth))
    }

    private var selectedMonthEntries: [SpendingTrackerEntry] {
        let range = selectedMonthRange
        return entries.filter { $0.dayString >= range.start && $0.dayString < range.end }
    }

    var selectedMonthDisplayName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonthDate)
    }

    // MARK: - Today Computed Properties

    var todayEntries: [SpendingTrackerEntry] {
        entries
            .filter { $0.dayString == todayString }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
    }

    var todayTotal: Double {
        todayEntries.reduce(0) { $0 + $1.amount }
    }

    var dailyBudgetRemaining: Double {
        max(0, dailyBudget - todayTotal)
    }

    var dailyBudgetProgress: Double {
        guard dailyBudget > 0 else { return 0 }
        return min(1.0, todayTotal / dailyBudget)
    }

    var isOverBudget: Bool {
        todayTotal > dailyBudget
    }

    // MARK: - Monthly Computed Properties

    var currentMonthTotal: Double {
        selectedMonthEntries.reduce(0) { $0 + $1.amount }
    }

    var categoryBreakdown: [CategoryBreakdownItem] {
        let monthEntries = selectedMonthEntries
        let total = monthEntries.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        var grouped: [SpendingCategory: Double] = [:]
        for entry in monthEntries {
            grouped[entry.category, default: 0] += entry.amount
        }

        return grouped
            .map { CategoryBreakdownItem(category: $0.key, total: $0.value, percentage: ($0.value / total) * 100) }
            .sorted { $0.total > $1.total }
    }

    var topCategoryThisMonth: SpendingCategory? {
        // Use current month (offset 0) regardless of selectedMonthOffset
        let comps = calendar.dateComponents([.year, .month], from: Date())
        guard let monthStart = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
        let startStr = dayString(for: monthStart)
        let endStr = dayString(for: nextMonth)
        let thisMonthEntries = entries.filter { $0.dayString >= startStr && $0.dayString < endStr }

        var grouped: [SpendingCategory: Double] = [:]
        for entry in thisMonthEntries {
            grouped[entry.category, default: 0] += entry.amount
        }
        return grouped.max(by: { $0.value < $1.value })?.key
    }

    var noSpendDaysThisMonth: Int {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        guard let monthStart = calendar.date(from: comps) else { return 0 }

        let today = todayStart
        var count = 0
        var current = monthStart
        while current < today {
            let ds = dayString(for: current)
            if totalForDay(ds) == 0 {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return count
    }

    // MARK: - Weekly Computed Properties

    private var currentWeekMonday: Date {
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2 // Monday
        return calendar.date(from: comps) ?? todayStart
    }

    var thisWeekDailyTotals: [Double] {
        let monday = currentWeekMonday
        let today = todayStart
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return 0 }
            if day > today { return 0 }
            return totalForDay(dayString(for: day))
        }
    }

    var thisWeekTotal: Double {
        thisWeekDailyTotals.reduce(0, +)
    }

    var lastWeekTotal: Double {
        guard let lastMonday = calendar.date(byAdding: .day, value: -7, to: currentWeekMonday) else { return 0 }
        return (0..<7).reduce(0) { total, offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: lastMonday) else { return total }
            return total + totalForDay(dayString(for: day))
        }
    }

    var weekOverWeekChange: Double {
        guard lastWeekTotal > 0 else { return 0 }
        return ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100
    }

    // MARK: - 30-Day Average

    var averageDailySpend: Double {
        var daysWithData = 0
        var totalSpend: Double = 0
        let today = todayStart

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayTotal = totalForDay(dayString(for: day))
            if dayTotal > 0 {
                daysWithData += 1
                totalSpend += dayTotal
            }
        }

        guard daysWithData > 0 else { return 0 }
        return totalSpend / Double(daysWithData)
    }

    // MARK: - Streak Calculations

    var currentStreak: Int {
        var streak = 0
        let today = todayStart

        // Check today first
        if todayTotal <= dailyBudget {
            streak = 1
        } else {
            return 0
        }

        // Walk backwards from yesterday
        var offset = 1
        while true {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let dayTotal = totalForDay(dayString(for: day))
            // Days with zero spending count (under budget)
            if dayTotal <= dailyBudget {
                streak += 1
            } else {
                break
            }
            offset += 1
            if offset > 365 { break } // Safety limit
        }

        return streak
    }

    var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }

        // Get all unique days from entries, plus fill gaps
        let sortedDays = Set(entries.map { $0.dayString }).sorted()
        guard let firstDayStr = sortedDays.first,
              let firstDate = parseShortDate(firstDayStr) else { return 0 }

        let today = todayStart
        var longest = 0
        var current = 0
        var checkDate = firstDate

        while checkDate <= today {
            let ds = dayString(for: checkDate)
            let dayTotal = totalForDay(ds)
            if dayTotal <= dailyBudget {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = next
        }

        return longest
    }

    private func parseShortDate(_ dateStr: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateStr)
    }

    // MARK: - Chart Data

    var weeklyChartData: [ChartDataPoint] {
        let monday = currentWeekMonday
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return (0..<7).map { offset in
            ChartDataPoint(label: dayLabels[offset], value: thisWeekDailyTotals[offset])
        }
    }

    var categoryChartData: [ChartDataPoint] {
        categoryBreakdown.map { item in
            ChartDataPoint(label: item.category.displayName, value: item.total)
        }
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // 1. Today's budget status
        if isOverBudget {
            let overage = String(format: "$%.2f", todayTotal - dailyBudget)
            result.append(ModuleInsight(
                type: .warning,
                title: "Over Budget",
                message: "You've exceeded today's budget by \(overage)."
            ))
        } else if todayTotal > 0 {
            let remaining = String(format: "$%.2f", dailyBudgetRemaining)
            result.append(ModuleInsight(
                type: .trend,
                title: "Budget Status",
                message: "You have \(remaining) remaining in today's budget."
            ))
        }

        // 2. Week-over-week change
        if lastWeekTotal > 0 {
            let change = weekOverWeekChange
            let direction = change >= 0 ? "more" : "less"
            let pct = String(format: "%.0f%%", abs(change))
            result.append(ModuleInsight(
                type: change > 10 ? .warning : (change < -5 ? .achievement : .trend),
                title: "Weekly Trend",
                message: "You're spending \(pct) \(direction) than last week."
            ))
        }

        // 3. Top spending category this month
        if let topCat = topCategoryThisMonth,
           let breakdown = categoryBreakdown.first(where: { $0.category == topCat }) {
            let pct = String(format: "%.0f%%", breakdown.percentage)
            result.append(ModuleInsight(
                type: .trend,
                title: "Top Category",
                message: "\(topCat.displayName) is your biggest expense this month at \(pct) of total spending."
            ))
        }

        // 4. No-spend days
        let noSpend = noSpendDaysThisMonth
        if noSpend > 0 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "No-Spend Days",
                message: "You've had \(noSpend) no-spend day\(noSpend == 1 ? "" : "s") this month!"
            ))
        }

        // 5. Biggest expense this week
        let monday = currentWeekMonday
        let weekEntries = entries.filter {
            guard let d = $0.parsedDate else { return false }
            return d >= monday && d <= Date()
        }
        if let biggest = weekEntries.max(by: { $0.amount < $1.amount }), biggest.amount > 0 {
            result.append(ModuleInsight(
                type: .trend,
                title: "Biggest Expense",
                message: "\(biggest.category.displayName) — \(biggest.formattedAmount)\(biggest.note.isEmpty ? "" : " (\(biggest.note))")"
            ))
        }

        // 6. Budget adherence rate (last 30 days)
        let today = todayStart
        var daysUnder = 0
        var totalDays = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            totalDays += 1
            if totalForDay(dayString(for: day)) <= dailyBudget {
                daysUnder += 1
            }
        }
        if totalDays > 0 {
            let rate = String(format: "%.0f%%", Double(daysUnder) / Double(totalDays) * 100)
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Budget Adherence",
                message: "You stayed under budget \(rate) of the last 30 days."
            ))
        }

        // 7. Streak
        if currentStreak >= 3 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Under-Budget Streak",
                message: "\(currentStreak) days in a row under budget! Keep it going!"
            ))
        }

        return result
    }

    // MARK: - Month Navigation

    func previousMonth() {
        selectedMonthOffset -= 1
    }

    func nextMonth() {
        if selectedMonthOffset < 0 {
            selectedMonthOffset += 1
        }
    }

    var canGoNextMonth: Bool {
        selectedMonthOffset < 0
    }

    // MARK: - Selected Month Average Daily

    var selectedMonthAverageDaily: Double {
        let comps = calendar.dateComponents([.year, .month], from: selectedMonthDate)
        guard let monthStart = calendar.date(from: comps) else { return 0 }

        let today = todayStart
        let endDate: Date
        if selectedMonthOffset == 0 {
            endDate = today
        } else {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return 0 }
            endDate = nextMonth
        }

        let daysElapsed = max(1, calendar.dateComponents([.day], from: monthStart, to: endDate).day ?? 1)
        return currentMonthTotal / Double(daysElapsed)
    }
}

// MARK: - Double Extension

private extension Optional where Wrapped == Double {
    var nonZero: Double? {
        guard let value = self, value > 0 else { return nil }
        return value
    }
}