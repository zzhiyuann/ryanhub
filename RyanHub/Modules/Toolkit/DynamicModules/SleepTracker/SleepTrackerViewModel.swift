import Foundation

@Observable
@MainActor
final class SleepTrackerViewModel {

    // MARK: - State

    var entries: [SleepTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyGoal: Double = SleepTrackerConstants.defaultDailyGoal

    // MARK: - Bridge URL

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    // MARK: - Init

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/sleepTracker/data") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fetched = try decoder.decode([SleepTrackerEntry].self, from: data)
            entries = fetched.sorted { $0.date > $1.date }
            UserDefaults.standard.set(data, forKey: "dynamic_module_sleepTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: SleepTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/sleepTracker/data/add") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: SleepTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/sleepTracker/data?id=\(entry.id)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    var recentEntries: [SleepTrackerEntry] {
        entries.prefix(SleepTrackerConstants.weeklyWindow).map { $0 }
    }

    private func entries(inLast days: Int) -> [SleepTrackerEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { entry in
            guard let d = entry.calendarDate else { return false }
            return d >= cutoff
        }
    }

    private func entriesForDay(_ date: Date) -> [SleepTrackerEntry] {
        entries.filter { entry in
            guard let d = entry.calendarDate else { return false }
            return Calendar.current.isDate(d, inSameDayAs: date)
        }
    }

    // MARK: - Last Night

    var lastNightEntry: SleepTrackerEntry? {
        entries.first
    }

    var lastNightSleepHours: Double {
        entries.first?.durationHours ?? 0.0
    }

    var lastNightQuality: Int {
        entries.first?.qualityRating ?? 0
    }

    // MARK: - Goal Progress

    var goalProgress: Double {
        min(lastNightSleepHours / dailyGoal, 1.0)
    }

    var lastNightGoalProgress: Double { goalProgress }

    // MARK: - Weekly Averages

    var weeklyAverageHours: Double {
        let week = entries(inLast: SleepTrackerConstants.weeklyWindow)
        guard !week.isEmpty else { return 0.0 }
        return week.map { $0.durationHours }.reduce(0, +) / Double(week.count)
    }

    var weeklyAverageDurationFormatted: String {
        let h = Int(weeklyAverageHours)
        let m = Int((weeklyAverageHours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var weeklyAverageQuality: Double {
        let week = entries(inLast: SleepTrackerConstants.weeklyWindow)
        guard !week.isEmpty else { return 0.0 }
        return week.map { Double($0.qualityRating) }.reduce(0, +) / Double(week.count)
    }

    // MARK: - Sleep Debt

    var sleepDebtHours: Double {
        let week = entries(inLast: SleepTrackerConstants.weeklyWindow)
        let totalLogged = week.map { $0.durationHours }.reduce(0, +)
        return (dailyGoal * Double(week.count)) - totalLogged
    }

    // MARK: - Streak

    var currentStreak: Int {
        var streak = 0
        var date = Calendar.current.startOfDay(for: Date())
        for _ in 0..<365 {
            let dayEntries = entriesForDay(date)
            let met = dayEntries.first(where: { $0.durationHours >= dailyGoal }) != nil
            if met {
                streak += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            } else {
                // If today has no entries yet, skip and check yesterday
                if Calendar.current.isDateInToday(date) && dayEntries.isEmpty {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    continue
                }
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let qualifyingDays = Set(entries.compactMap { $0.calendarDate })
            .filter { date in
                let dayEntries = entriesForDay(date)
                return dayEntries.contains { $0.durationHours >= dailyGoal }
            }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        guard !qualifyingDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<qualifyingDays.count {
            if let diff = calendar.dateComponents([.day], from: qualifyingDays[i - 1], to: qualifyingDays[i]).day, diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    var isActiveToday: Bool {
        !entriesForDay(Date()).isEmpty
    }

    var totalEntries: Int { entries.count }

    var bestSleepEntry: SleepTrackerEntry? {
        entries.max(by: { $0.durationHours < $1.durationHours })
    }

    // MARK: - Bedtime Consistency

    var bedtimeConsistencyScore: Double {
        let recent = Array(entries.prefix(SleepTrackerConstants.consistencyWindow))
        guard recent.count >= 2 else { return 100.0 }

        let hours = recent.map { $0.normalizedBedtimeHour }
        let mean = hours.reduce(0, +) / Double(hours.count)
        let variance = hours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hours.count)
        let sdHours = variance.squareRoot()
        let sdMinutes = sdHours * 60.0

        if sdMinutes <= SleepTrackerConstants.consistencyPerfectSD { return 100.0 }
        if sdMinutes >= SleepTrackerConstants.consistencyWorstSD { return 0.0 }

        let range = SleepTrackerConstants.consistencyWorstSD - SleepTrackerConstants.consistencyPerfectSD
        let normalized = (sdMinutes - SleepTrackerConstants.consistencyPerfectSD) / range
        return max(0.0, min(100.0, (1.0 - normalized) * 100.0))
    }

    // MARK: - Sleep Score

    var sleepScore: Int {
        // Duration component (40%): max score at 7–9h range
        let durationScore: Double = {
            let h = lastNightSleepHours
            if h >= SleepTrackerConstants.optimalMinHours && h <= SleepTrackerConstants.optimalMaxHours {
                return 100.0
            } else if h < SleepTrackerConstants.optimalMinHours {
                return max(0.0, (h / SleepTrackerConstants.optimalMinHours) * 100.0)
            } else {
                // Over 9h — slight penalty
                let excess = h - SleepTrackerConstants.optimalMaxHours
                return max(0.0, 100.0 - (excess * 10.0))
            }
        }()

        // Quality component (35%): 1–5 maps to 0–100
        let qualityScore: Double = {
            let q = Double(lastNightQuality)
            let min = Double(SleepTrackerConstants.minQualityRating)
            let max = Double(SleepTrackerConstants.maxQualityRating)
            return ((q - min) / (max - min)) * 100.0
        }()

        // Consistency component (25%)
        let consistencyScore = bedtimeConsistencyScore

        let composite = (durationScore * 0.40) + (qualityScore * 0.35) + (consistencyScore * 0.25)
        return Int(min(100.0, max(0.0, composite)))
    }

    // MARK: - Trends

    private func avgQuality(for window: [SleepTrackerEntry]) -> Double {
        guard !window.isEmpty else { return 0 }
        return window.map { Double($0.qualityRating) }.reduce(0, +) / Double(window.count)
    }

    private func avgDuration(for window: [SleepTrackerEntry]) -> Double {
        guard !window.isEmpty else { return 0 }
        return window.map { $0.durationHours }.reduce(0, +) / Double(window.count)
    }

    var qualityTrend: String {
        let thisWeek = entries(inLast: 7)
        let lastWeekCutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let midCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let lastWeek = entries.filter { entry in
            guard let d = entry.calendarDate else { return false }
            return d >= lastWeekCutoff && d < midCutoff
        }

        let thisAvg = avgQuality(for: thisWeek)
        let lastAvg = avgQuality(for: lastWeek)
        let diff = thisAvg - lastAvg

        if diff > SleepTrackerConstants.trendQualityThreshold { return "improving" }
        if diff < -SleepTrackerConstants.trendQualityThreshold { return "declining" }
        return "stable"
    }

    var durationTrend: String {
        let thisWeek = entries(inLast: 7)
        let lastWeekCutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let midCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let lastWeek = entries.filter { entry in
            guard let d = entry.calendarDate else { return false }
            return d >= lastWeekCutoff && d < midCutoff
        }

        let thisAvg = avgDuration(for: thisWeek)
        let lastAvg = avgDuration(for: lastWeek)
        let diff = thisAvg - lastAvg

        if diff > SleepTrackerConstants.trendDurationThreshold { return "improving" }
        if diff < -SleepTrackerConstants.trendDurationThreshold { return "declining" }
        return "stable"
    }

    // MARK: - Chart Data

    var weeklyChartData: [(label: String, value: Double)] {
        var result: [(label: String, value: Double)] = []
        let cal = Calendar.current
        for offset in (0..<7).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let dayEntries = entriesForDay(day)
            let total = dayEntries.map { $0.durationHours }.reduce(0, +)
            let f = DateFormatter()
            f.dateFormat = "EEE"
            let label = f.string(from: day)
            result.append((label: label, value: total))
        }
        return result
    }

    // MARK: - Distributions

    var qualityDistribution: [Int: Int] {
        var dist: [Int: Int] = [:]
        for rating in SleepTrackerConstants.minQualityRating...SleepTrackerConstants.maxQualityRating {
            dist[rating] = 0
        }
        for entry in entries {
            dist[entry.qualityRating, default: 0] += 1
        }
        return dist
    }

    var moodDistribution: [WakeUpMood: Int] {
        var dist: [WakeUpMood: Int] = [:]
        for mood in WakeUpMood.allCases { dist[mood] = 0 }
        for entry in entries { dist[entry.wakeUpMood, default: 0] += 1 }
        return dist
    }

    // MARK: - Top Disruptor

    var topDisruptor: SleepDisruptor? {
        let recent = Array(entries.prefix(SleepTrackerConstants.insightLookback))
        var counts: [SleepDisruptor: Int] = [:]
        for entry in recent where entry.sleepDisruptor.isActive {
            counts[entry.sleepDisruptor, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Best Sleep Day of Week

    var bestSleepDayOfWeek: String {
        var dayQuality: [String: [Int]] = [:]
        for entry in entries {
            let day = entry.dayOfWeekAbbreviation
            guard !day.isEmpty else { continue }
            dayQuality[day, default: []].append(entry.qualityRating)
        }
        let avgByDay = dayQuality.mapValues { ratings -> Double in
            ratings.map(Double.init).reduce(0, +) / Double(ratings.count)
        }
        return avgByDay.max(by: { $0.value < $1.value })?.key ?? "—"
    }

    // MARK: - Insights

    var insights: [String] {
        var result: [String] = []

        // Sleep debt alert
        if sleepDebtHours > 1.0 {
            let formatted = String(format: "%.1f", sleepDebtHours)
            result.append("You're running a \(formatted)h sleep debt this week — consider an earlier bedtime tonight.")
        }

        // Disruptor correlation
        if let disruptor = topDisruptor {
            let disruptorEntries = entries.filter { $0.sleepDisruptor == disruptor }
            let normalEntries = entries.filter { $0.sleepDisruptor == .none }
            if !disruptorEntries.isEmpty && !normalEntries.isEmpty {
                let disruptorHours = avgDuration(for: disruptorEntries)
                let normalHours = avgDuration(for: normalEntries)
                let disruptorQuality = avgQuality(for: disruptorEntries)
                let normalQuality = avgQuality(for: normalEntries)
                let hoursDiff = String(format: "%.1f", normalHours - disruptorHours)
                let qualityDiff = String(format: "%.1f", normalQuality - disruptorQuality)
                result.append("Nights with \(disruptor.displayName) average \(hoursDiff)h fewer sleep and \(qualityDiff) lower quality.")
            }
        }

        // Weekend vs weekday differential
        let weekendEntries = entries.filter { $0.isWeekend }
        let weekdayEntries = entries.filter { !$0.isWeekend }
        if !weekendEntries.isEmpty && !weekdayEntries.isEmpty {
            let weekendAvg = avgDuration(for: weekendEntries)
            let weekdayAvg = avgDuration(for: weekdayEntries)
            let diff = weekendAvg - weekdayAvg
            if abs(diff) > 0.25 {
                let diffMinutes = Int(abs(diff) * 60)
                let direction = diff > 0 ? "more" : "less"
                result.append("You sleep \(diffMinutes)min \(direction) on weekends — \(diff > 0 ? "a sign of weekday under-sleeping" : "great weekday consistency").")
            }
        }

        // Bedtime drift (compare last 14 days to prior 14 days)
        let recentBedtimes = Array(entries.prefix(14))
        let olderBedtimes = Array(entries.dropFirst(14).prefix(14))
        if !recentBedtimes.isEmpty && !olderBedtimes.isEmpty {
            let recentAvg = recentBedtimes.map { $0.normalizedBedtimeHour }.reduce(0, +) / Double(recentBedtimes.count)
            let olderAvg = olderBedtimes.map { $0.normalizedBedtimeHour }.reduce(0, +) / Double(olderBedtimes.count)
            let driftMinutes = Int(abs(recentAvg - olderAvg) * 60)
            if driftMinutes >= 15 {
                let direction = recentAvg > olderAvg ? "later" : "earlier"
                result.append("Your average bedtime shifted \(driftMinutes)min \(direction) compared to last month.")
            }
        }

        // Quality-mood link
        let highQualityEntries = entries.filter { $0.qualityRating >= 4 }
        if highQualityEntries.count >= 3 {
            let positiveCount = highQualityEntries.filter {
                $0.wakeUpMood == .energized || $0.wakeUpMood == .rested
            }.count
            let pct = Int((Double(positiveCount) / Double(highQualityEntries.count)) * 100)
            result.append("When quality is 4+, you wake up Energized or Rested \(pct)% of the time.")
        }

        // Consistency reward
        if bedtimeConsistencyScore >= 85 {
            result.append("Your bedtime consistency is excellent this week — keep it up!")
        }

        // Dream correlation
        let dreamEntries = entries.filter { $0.dreamRecall && $0.qualityRating >= 4 }
        let highQualityTotal = entries.filter { $0.qualityRating >= 4 }
        if highQualityTotal.count >= 3 {
            let pct = Int((Double(dreamEntries.count) / Double(highQualityTotal.count)) * 100)
            result.append("You recall dreams on \(pct)% of nights rated quality 4+.")
        }

        // Streak celebration
        if currentStreak >= 3 {
            result.append("\(currentStreak)-day streak! You've met your sleep goal every night.")
        }

        return result
    }

    // MARK: - Chart Data for ModuleChartView

    var chartData: [ChartDataPoint] {
        weeklyChartData.map { ChartDataPoint(label: $0.label, value: $0.value) }
    }

    // MARK: - Module Insights for ModuleInsight

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        if sleepDebtHours > 1.0 {
            let formatted = String(format: "%.1f", sleepDebtHours)
            result.append(ModuleInsight(
                type: .warning,
                title: "Sleep Debt",
                message: "You're running a \(formatted)h sleep debt this week — consider an earlier bedtime tonight."
            ))
        }

        if currentStreak >= 3 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(currentStreak)-Day Streak",
                message: "You've met your sleep goal every night. Keep it up!"
            ))
        }

        if qualityTrend == "improving" {
            result.append(ModuleInsight(
                type: .trend,
                title: "Quality Improving",
                message: "Your sleep quality is trending up compared to last week."
            ))
        } else if qualityTrend == "declining" {
            result.append(ModuleInsight(
                type: .trend,
                title: "Quality Declining",
                message: "Your sleep quality has dipped compared to last week."
            ))
        }

        if bedtimeConsistencyScore >= 85 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Consistent Bedtime",
                message: "Your bedtime consistency score is \(Int(bedtimeConsistencyScore))/100 — excellent!"
            ))
        } else if bedtimeConsistencyScore < 40 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Irregular Bedtime",
                message: "Try going to bed at the same time each night to improve sleep quality."
            ))
        }

        if let disruptor = topDisruptor {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Top Disruptor: \(disruptor.displayName)",
                message: "This has been your most common sleep disruptor recently."
            ))
        }

        return result
    }
}