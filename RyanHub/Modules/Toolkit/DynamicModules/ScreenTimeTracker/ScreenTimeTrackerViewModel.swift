import Foundation

// MARK: - ScreenTimeTrackerViewModel

@Observable
@MainActor
final class ScreenTimeTrackerViewModel {
    var entries: [ScreenTimeTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyGoalHours: Double = 4.0

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() {
        dailyGoalHours = UserDefaults.standard.double(forKey: "screenTimeTracker_dailyGoalHours")
        if dailyGoalHours < 1.0 { dailyGoalHours = 4.0 }
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let url = URL(string: "\(bridgeBaseURL)/modules/screenTimeTracker/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([ScreenTimeTrackerEntry].self, from: data)
            entries = decoded
            UserDefaults.standard.set(data, forKey: "dynamic_module_screenTimeTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(category: ScreenTimeCategory, durationMinutes: Int, intentional: Bool, notes: String) async {
        let entry = ScreenTimeTrackerEntry(
            category: category,
            durationMinutes: durationMinutes,
            intentional: intentional,
            notes: notes
        )
        guard let url = URL(string: "\(bridgeBaseURL)/modules/screenTimeTracker/data/add") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: ScreenTimeTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/screenTimeTracker/data?id=\(entry.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDailyGoal(_ hours: Double) {
        dailyGoalHours = min(12.0, max(1.0, hours))
        UserDefaults.standard.set(dailyGoalHours, forKey: "screenTimeTracker_dailyGoalHours")
    }

    // MARK: - Date Helpers

    private var calendar: Calendar { Calendar.current }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func date(daysAgo n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: startOfDay(Date()))!
    }

    private func totalMinutes(for date: Date) -> Int {
        entries
            .filter { calendar.isDate(entryDate($0), inSameDayAs: date) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private func entriesOn(_ date: Date) -> [ScreenTimeTrackerEntry] {
        entries.filter { calendar.isDate(entryDate($0), inSameDayAs: date) }
    }

    private func entryDate(_ entry: ScreenTimeTrackerEntry) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: entry.date) ?? Date.distantPast
    }

    var todayEntries: [ScreenTimeTrackerEntry] {
        entriesOn(Date())
    }

    var weekEntries: [ScreenTimeTrackerEntry] {
        let cutoff = date(daysAgo: 6)
        return entries.filter { entryDate($0) >= cutoff }
    }

    // MARK: - Computed Properties

    var todayTotalMinutes: Int {
        todayEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var todayTotalHours: Double {
        (Double(todayTotalMinutes) / 60.0 * 10).rounded() / 10
    }

    var goalProgressPercent: Double {
        let goalMinutes = dailyGoalHours * 60.0
        guard goalMinutes > 0 else { return 0 }
        return min(1.5, Double(todayTotalMinutes) / goalMinutes)
    }

    var isUnderGoalToday: Bool {
        Double(todayTotalMinutes) <= dailyGoalHours * 60.0
    }

    var currentStreak: Int {
        let goalMinutes = dailyGoalHours * 60.0
        var streak = 0
        var dayOffset = 0
        // Start from today, then go back
        while true {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: startOfDay(Date()))!
            let dayEntries = entriesOn(day)
            let dayTotal = dayEntries.reduce(0) { $0 + $1.durationMinutes }
            if dayEntries.isEmpty {
                // Days with zero entries pause streak (don't break, don't extend)
                dayOffset += 1
                if dayOffset > 365 { break }
                continue
            }
            if Double(dayTotal) <= goalMinutes {
                streak += 1
                dayOffset += 1
            } else {
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let goalMinutes = dailyGoalHours * 60.0
        // Collect all unique days that have entries, sorted ascending
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        var dayTotals: [Date: Int] = [:]
        for entry in entries {
            let d = startOfDay(entryDate(entry))
            dayTotals[d, default: 0] += entry.durationMinutes
        }
        let qualifyingDays = Set(dayTotals.filter { Double($0.value) <= goalMinutes }.keys)
        let allDays = dayTotals.keys.sorted()
        var best = 0
        var current = 0
        for day in allDays {
            if qualifyingDays.contains(day) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    var weeklyAverageMinutes: Double {
        let total = (0..<7).reduce(0) { $0 + totalMinutes(for: date(daysAgo: $1)) }
        return Double(total) / 7.0
    }

    var weekOverWeekChange: Double {
        let thisWeek = (0..<7).reduce(0.0) { $0 + Double(totalMinutes(for: date(daysAgo: $1))) } / 7.0
        let lastWeek = (7..<14).reduce(0.0) { $0 + Double(totalMinutes(for: date(daysAgo: $1))) } / 7.0
        guard lastWeek > 0 else { return 0 }
        return (thisWeek - lastWeek) / lastWeek * 100.0
    }

    var categoryBreakdownToday: [(ScreenTimeCategory, Int)] {
        var totals: [ScreenTimeCategory: Int] = [:]
        for entry in todayEntries {
            totals[entry.category, default: 0] += entry.durationMinutes
        }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var weeklyTrendData: [(Date, Int)] {
        (0..<7).reversed().map { offset in
            let day = date(daysAgo: offset)
            return (day, totalMinutes(for: day))
        }
    }

    var mostUsedCategory: ScreenTimeCategory? {
        var totals: [ScreenTimeCategory: Int] = [:]
        for entry in weekEntries {
            totals[entry.category, default: 0] += entry.durationMinutes
        }
        return totals.max { $0.value < $1.value }?.key
    }

    var intentionalUsePercent: Double {
        let total = weekEntries.reduce(0) { $0 + $1.durationMinutes }
        guard total > 0 else { return 0 }
        let intentional = weekEntries.filter { $0.intentional }.reduce(0) { $0 + $1.durationMinutes }
        return Double(intentional) / Double(total) * 100.0
    }

    var bestDayThisWeek: (Date, Int)? {
        let days = (0..<7).map { offset -> (Date, Int) in
            let day = date(daysAgo: offset)
            return (day, totalMinutes(for: day))
        }.filter { $0.1 > 0 }
        return days.min { $0.1 < $1.1 }
    }

    // MARK: - Chart Data

    var chartData: [ChartDataPoint] {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return weeklyTrendData.map { (day, minutes) in
            ChartDataPoint(label: df.string(from: day), value: Double(minutes) / 60.0)
        }
    }

    // MARK: - Insights

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Streak milestones
        let streak = currentStreak
        let milestones = [3, 7, 14, 30, 60, 90]
        if milestones.contains(streak) {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(streak)-Day Streak!",
                message: "You've stayed under your screen time goal for \(streak) days in a row. Keep it up!"
            ))
        }

        // Week-over-week delta
        let wow = weekOverWeekChange
        if abs(wow) >= 5 {
            if wow < 0 {
                let pct = Int(abs(wow).rounded())
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Screen Time Down",
                    message: "Your screen time is down \(pct)% compared to last week — great progress!"
                ))
            } else {
                let pct = Int(wow.rounded())
                let topCat = mostUsedCategory?.displayName ?? "Unknown"
                result.append(ModuleInsight(
                    type: .warning,
                    title: "Screen Time Up",
                    message: "Screen time increased \(pct)% this week — your \(topCat) usage drove most of the increase."
                ))
            }
        }

        // Category dominance alert
        let weekTotal = weekEntries.reduce(0) { $0 + $1.durationMinutes }
        if weekTotal > 0 {
            var catTotals: [ScreenTimeCategory: Int] = [:]
            for entry in weekEntries {
                catTotals[entry.category, default: 0] += entry.durationMinutes
            }
            for (cat, mins) in catTotals {
                let share = Double(mins) / Double(weekTotal) * 100.0
                if share > 40 {
                    result.append(ModuleInsight(
                        type: .warning,
                        title: "Category Dominance",
                        message: "\(cat.displayName) accounts for \(Int(share.rounded()))% of your screen time this week."
                    ))
                }
            }
        }

        // Intentional use assessment
        let intentPct = intentionalUsePercent
        if weekTotal > 0 && intentPct < 50 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Mindful Usage",
                message: "Only \(Int(intentPct.rounded()))% of your screen time was intentional this week — try setting purpose before picking up your phone."
            ))
        }

        // Mindless usage warning (>60% non-intentional)
        if weekTotal > 0 && (100 - intentPct) > 60 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Mostly Mindless",
                message: "More than 60% of your screen time was unintentional. Pause and set an intention before each session."
            ))
        }

        // Best day spotlight
        if let (bestDay, bestMins) = bestDayThisWeek {
            let df = DateFormatter()
            df.dateFormat = "EEEE"
            let dayName = df.string(from: bestDay)
            let hours = (Double(bestMins) / 60.0 * 10).rounded() / 10
            result.append(ModuleInsight(
                type: .achievement,
                title: "Best Day This Week",
                message: "\(dayName) was your lightest day at just \(hours)h — what made it work?"
            ))
        }

        // Goal calibration
        let daysUnderGoal = (0..<7).filter { offset in
            let day = date(daysAgo: offset)
            let dayEntries = entriesOn(day)
            guard !dayEntries.isEmpty else { return false }
            return Double(dayEntries.reduce(0) { $0 + $1.durationMinutes }) <= dailyGoalHours * 60.0
        }.count
        if daysUnderGoal >= 6 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Lower Your Goal?",
                message: "You've been under your \(dailyGoalHours)h goal \(daysUnderGoal) of the last 7 days. Consider lowering it by 0.5h to keep challenging yourself."
            ))
        }
        let daysOverGoal = (0..<7).filter { offset in
            let day = date(daysAgo: offset)
            let dayEntries = entriesOn(day)
            guard !dayEntries.isEmpty else { return false }
            return Double(dayEntries.reduce(0) { $0 + $1.durationMinutes }) > dailyGoalHours * 60.0
        }.count
        if daysOverGoal >= 5 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Adjust Your Goal",
                message: "You've exceeded your \(dailyGoalHours)h goal \(daysOverGoal) of the last 7 days. Consider raising it or breaking it into category sub-budgets."
            ))
        }

        // Weekend vs weekday pattern detection
        let weekdayAvg = averageMinutes(for: [2, 3, 4, 5, 6]) // Mon-Fri
        let saturdayAvg = averageMinutesForWeekday(7)
        let sundayAvg = averageMinutesForWeekday(1)
        let weekendAvg = (saturdayAvg + sundayAvg) / 2.0
        if weekendAvg > weekdayAvg * 1.3 && weekdayAvg > 0 {
            let wkdH = (weekdayAvg / 60.0 * 10).rounded() / 10
            let wkndH = (weekendAvg / 60.0 * 10).rounded() / 10
            result.append(ModuleInsight(
                type: .trend,
                title: "Weekend Spikes",
                message: "Your weekend screen time averages \(wkndH)h vs \(wkdH)h on weekdays."
            ))
        }

        return result
    }

    var insights: [String] {
        moduleInsights.map { "\($0.title): \($0.message)" }
    }

    // MARK: - Private Helpers

    private func averageMinutes(for weekdays: [Int]) -> Double {
        // weekday: 1=Sun, 2=Mon ... 7=Sat
        let relevant = entries.filter {
            let wd = calendar.component(.weekday, from: entryDate($0))
            return weekdays.contains(wd)
        }
        guard !relevant.isEmpty else { return 0 }
        var dayTotals: [Date: Int] = [:]
        for entry in relevant {
            let d = startOfDay(entryDate(entry))
            dayTotals[d, default: 0] += entry.durationMinutes
        }
        return dayTotals.values.reduce(0.0) { $0 + Double($1) } / Double(dayTotals.count)
    }

    private func averageMinutesForWeekday(_ weekday: Int) -> Double {
        averageMinutes(for: [weekday])
    }
}