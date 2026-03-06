import Foundation

// MARK: - MoodJournal ViewModel

@Observable
@MainActor
final class MoodJournalViewModel {
    var entries: [MoodJournalEntry] = []
    var isLoading = false
    var errorMessage: String?
    var selectedTab: MoodJournalTab = .today
    var showingCheckIn = false

    enum MoodJournalTab: String, CaseIterable {
        case today = "Today"
        case calendar = "Calendar"
        case trends = "Trends"
    }

    // MARK: - Bridge Server

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    private let moduleId = "moodJournal"
    private let calendar = Calendar.current

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            entries = try decoder.decode([MoodJournalEntry].self, from: data)
            cacheForDataProvider()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: MoodJournalEntry) async {
        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data/add") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            entries.append(entry)
            entries.sort { $0.date > $1.date }
            cacheForDataProvider()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: MoodJournalEntry) async {
        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data?id=\(entry.id)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            entries.removeAll { $0.id == entry.id }
            cacheForDataProvider()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Cache

    private func cacheForDataProvider() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "dynamic_module_\(moduleId)_cache")
        }
    }

    // MARK: - Date Helpers

    private var today: Date { calendar.startOfDay(for: Date()) }

    private func startOfWeek(for date: Date) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? date
    }

    private func entriesForDay(_ day: Date) -> [MoodJournalEntry] {
        entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return calendar.isDate(d, inSameDayAs: day)
        }
    }

    private func averageRating(for filtered: [MoodJournalEntry]) -> Double {
        guard !filtered.isEmpty else { return 0 }
        return Double(filtered.reduce(0) { $0 + $1.rating }) / Double(filtered.count)
    }

    // MARK: - Computed: Today

    var todayEntries: [MoodJournalEntry] {
        entriesForDay(today).sorted { $0.date > $1.date }
    }

    var hasCheckedInToday: Bool {
        !todayEntries.isEmpty
    }

    // MARK: - Computed: Streaks

    var currentStreak: Int {
        let activeDays = Set(entries.compactMap { $0.calendarDate })
        guard !activeDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        // If no entry today, start from yesterday
        if !activeDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while activeDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    var longestStreak: Int {
        let activeDays = Set(entries.compactMap { $0.calendarDate })
        guard !activeDays.isEmpty else { return 0 }

        let sorted = activeDays.sorted()
        var longest = 1
        var current = 1

        for i in 1..<sorted.count {
            let daysBetween = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if daysBetween == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    // MARK: - Computed: Weekly Averages

    var weeklyAverage: Double {
        let weekStart = startOfWeek(for: today)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return 0 }
        let weekEntries = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= weekStart && d < weekEnd
        }
        return averageRating(for: weekEntries)
    }

    var previousWeekAverage: Double {
        let weekStart = startOfWeek(for: today)
        guard let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return 0 }
        let prevEntries = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= prevStart && d < weekStart
        }
        return averageRating(for: prevEntries)
    }

    var weeklyTrend: Double {
        weeklyAverage - previousWeekAverage
    }

    // MARK: - Computed: Monthly Mood Map

    var monthlyMoodMap: [Date: Double] {
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1), to: monthStart) else { return [:] }

        var map: [Date: [Int]] = [:]
        for entry in entries {
            guard let d = entry.parsedDate, d >= monthStart, d < monthEnd else { continue }
            let day = calendar.startOfDay(for: d)
            map[day, default: []].append(entry.rating)
        }

        var result: [Date: Double] = [:]
        for (day, ratings) in map {
            result[day] = Double(ratings.reduce(0, +)) / Double(ratings.count)
        }
        return result
    }

    // MARK: - Computed: Emotion Analysis

    var emotionCounts: [Emotion: Int] {
        guard let cutoff = calendar.date(byAdding: .day, value: -30, to: today) else { return [:] }
        let recent = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= cutoff
        }
        var counts: [Emotion: Int] = [:]
        for entry in recent {
            counts[entry.emotion, default: 0] += 1
        }
        return counts
    }

    var topEmotion: Emotion? {
        emotionCounts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Computed: Trend Chart Data

    var dailyAverages: [(date: Date, average: Double)] {
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: today) else { return [] }

        var dayMap: [Date: [Int]] = [:]
        for entry in entries {
            guard let d = entry.parsedDate else { continue }
            let day = calendar.startOfDay(for: d)
            if day >= startDate && day <= today {
                dayMap[day, default: []].append(entry.rating)
            }
        }

        var result: [(date: Date, average: Double)] = []
        var current = startDate
        while current <= today {
            if let ratings = dayMap[current], !ratings.isEmpty {
                let avg = Double(ratings.reduce(0, +)) / Double(ratings.count)
                result.append((date: current, average: avg))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    // MARK: - Computed: Best Day of Week

    var bestDayOfWeek: String {
        var dayTotals: [Int: (sum: Int, count: Int)] = [:]
        for entry in entries {
            guard let d = entry.parsedDate else { continue }
            let weekday = calendar.component(.weekday, from: d)
            let existing = dayTotals[weekday, default: (sum: 0, count: 0)]
            dayTotals[weekday] = (sum: existing.sum + entry.rating, count: existing.count + 1)
        }

        guard let best = dayTotals.max(by: {
            Double($0.value.sum) / Double($0.value.count) < Double($1.value.sum) / Double($1.value.count)
        }) else { return "N/A" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let symbols = formatter.weekdaySymbols ?? []
        let index = best.key - 1
        return index >= 0 && index < symbols.count ? symbols[index] : "N/A"
    }

    // MARK: - Energy-Mood Correlation

    var energyMoodCorrelation: Double {
        guard let cutoff = calendar.date(byAdding: .day, value: -30, to: today) else { return 0 }
        let recent = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= cutoff
        }
        guard recent.count >= 3 else { return 0 }

        let n = Double(recent.count)
        let moods = recent.map { Double($0.rating) }
        let energies = recent.map { Double($0.energyLevel) }

        let meanMood = moods.reduce(0, +) / n
        let meanEnergy = energies.reduce(0, +) / n

        var covariance = 0.0
        var varMood = 0.0
        var varEnergy = 0.0
        for i in 0..<recent.count {
            let dm = moods[i] - meanMood
            let de = energies[i] - meanEnergy
            covariance += dm * de
            varMood += dm * dm
            varEnergy += de * de
        }

        guard varMood > 0 && varEnergy > 0 else { return 0 }
        return covariance / (varMood.squareRoot() * varEnergy.squareRoot())
    }

    // MARK: - Chart Data

    var chartData: [ChartDataPoint] {
        dailyAverages.map { item in
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return ChartDataPoint(label: formatter.string(from: item.date), value: item.average)
        }
    }

    var emotionChartData: [ChartDataPoint] {
        emotionCounts
            .sorted { $0.value > $1.value }
            .map { ChartDataPoint(label: $0.key.displayName, value: Double($0.value)) }
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Week-over-week trend
        if previousWeekAverage > 0 {
            let pctChange = ((weeklyAverage - previousWeekAverage) / previousWeekAverage) * 100
            if weeklyTrend > 0.5 {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Mood Improving ↑",
                    message: "Your mood is up \(String(format: "%.0f", abs(pctChange)))% compared to last week. Keep it up!"
                ))
            } else if weeklyTrend < -0.5 {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Mood Dipping ↓",
                    message: "Your mood is down \(String(format: "%.0f", abs(pctChange)))% from last week. Consider what might be affecting you."
                ))
            } else {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Mood Stable →",
                    message: "Your mood has been consistent this week compared to last."
                ))
            }
        }

        // Best day of week
        if bestDayOfWeek != "N/A" {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Best Day: \(bestDayOfWeek)",
                message: "Historically, \(bestDayOfWeek) is your happiest day of the week."
            ))
        }

        // Top emotion
        if let top = topEmotion {
            let total = emotionCounts.values.reduce(0, +)
            let count = emotionCounts[top] ?? 0
            let pct = total > 0 ? Int(Double(count) / Double(total) * 100) : 0
            result.append(ModuleInsight(
                type: .trend,
                title: "Most Common: \(top.displayName)",
                message: "\(top.displayName) appears in \(pct)% of your recent check-ins."
            ))
        }

        // Streak milestones
        let streak = currentStreak
        if streak >= 100 {
            result.append(ModuleInsight(type: .achievement, title: "100-Day Streak! 🏆", message: "Incredible — \(streak) consecutive days of check-ins."))
        } else if streak >= 30 {
            result.append(ModuleInsight(type: .achievement, title: "30-Day Streak! 🔥", message: "A full month of daily check-ins. Amazing consistency."))
        } else if streak >= 7 {
            result.append(ModuleInsight(type: .achievement, title: "7-Day Streak! ✨", message: "One week strong — you're building a great habit."))
        } else if streak == 0 {
            result.append(ModuleInsight(type: .suggestion, title: "Start Your Streak", message: "Check in today to begin building your streak."))
        }

        // Energy-mood correlation
        let corr = energyMoodCorrelation
        if abs(corr) >= 0.3 {
            if corr > 0 {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Energy ↔ Mood Link",
                    message: "Your mood and energy are positively correlated. Higher energy days tend to bring better moods."
                ))
            } else {
                result.append(ModuleInsight(
                    type: .warning,
                    title: "Energy-Mood Mismatch",
                    message: "Interestingly, higher energy doesn't always mean better mood for you."
                ))
            }
        }

        // Monthly comparison
        let thisMonthComponents = calendar.dateComponents([.year, .month], from: today)
        if let thisMonthStart = calendar.date(from: thisMonthComponents),
           let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) {
            let thisMonthEntries = entries.filter { entry in
                guard let d = entry.parsedDate else { return false }
                return d >= thisMonthStart
            }
            let lastMonthEntries = entries.filter { entry in
                guard let d = entry.parsedDate else { return false }
                return d >= lastMonthStart && d < thisMonthStart
            }
            let thisAvg = averageRating(for: thisMonthEntries)
            let lastAvg = averageRating(for: lastMonthEntries)
            if lastAvg > 0 && thisAvg > 0 {
                let diff = thisAvg - lastAvg
                let direction = diff > 0.3 ? "up from" : diff < -0.3 ? "down from" : "similar to"
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Monthly Summary",
                    message: "This month's average mood (\(String(format: "%.1f", thisAvg))) is \(direction) last month (\(String(format: "%.1f", lastAvg)))."
                ))
            }
        }

        return result
    }

    // MARK: - Calendar Navigation

    var displayedMonth: Date = Date()

    func goToPreviousMonth() {
        if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = prev
        }
    }

    func goToNextMonth() {
        if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = next
        }
    }

    var displayedMonthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    func moodMapForDisplayedMonth() -> [Date: Double] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1), to: monthStart) else { return [:] }

        var map: [Date: [Int]] = [:]
        for entry in entries {
            guard let d = entry.parsedDate, d >= monthStart, d < monthEnd else { continue }
            let day = calendar.startOfDay(for: d)
            map[day, default: []].append(entry.rating)
        }

        var result: [Date: Double] = [:]
        for (day, ratings) in map {
            result[day] = Double(ratings.reduce(0, +)) / Double(ratings.count)
        }
        return result
    }

    func entriesForDate(_ date: Date) -> [MoodJournalEntry] {
        entriesForDay(date).sorted { $0.date > $1.date }
    }

    // MARK: - Latest Entry

    var latestEntry: MoodJournalEntry? {
        todayEntries.first
    }

    var latestMoodRating: Int {
        latestEntry?.rating ?? 5
    }
}