import Foundation

// MARK: - SleepTrackerTab

enum SleepTrackerTab: String, CaseIterable, Identifiable {
    case tonight = "Tonight"
    case week = "Week"
    case trends = "Trends"

    var id: String { rawValue }
}

// MARK: - SleepTrackerViewModel

@Observable
@MainActor
final class SleepTrackerViewModel {

    // MARK: - State

    var entries: [SleepTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var selectedTab: SleepTrackerTab = .tonight

    var sleepGoal: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: "sleepTracker_sleepGoal")
            return stored > 0 ? stored : 8.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sleepTracker_sleepGoal")
        }
    }

    // MARK: - Bridge Server

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

        guard let url = URL(string: "\(bridgeBaseURL)/modules/sleepTracker/data") else {
            errorMessage = "Invalid server URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([SleepTrackerEntry].self, from: data)
            cacheData(data)
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

    private func cacheData(_ data: Data) {
        UserDefaults.standard.set(data, forKey: "dynamic_module_sleepTracker_cache")
    }

    // MARK: - Computed: sleepDuration

    func sleepDuration(for entry: SleepTrackerEntry) -> Double {
        entry.sleepDuration
    }

    // MARK: - Computed: sleepScore

    func sleepScore(for entry: SleepTrackerEntry) -> Int {
        // Duration component (40%): 100 if equals goal, -12.5 per hour deviation
        let duration = entry.sleepDuration
        let durationDeviation = abs(duration - sleepGoal)
        let durationScore = max(0.0, 100.0 - durationDeviation * 12.5)

        // Quality component (40%): 1-5 mapped to 0-100
        let qualityScore = Double(entry.qualityRating - 1) * 25.0

        // Consistency component (20%): bedtime deviation from 30-day average
        let consistencyComponent: Double
        if let avgMinutes = averageBedtimeMinutesFromMidnight {
            let entryMinutes = entry.bedTimeMinutesFromMidnight
            let deviation = abs(entryMinutes - avgMinutes)
            if deviation <= 15.0 {
                consistencyComponent = 100.0
            } else if deviation >= 90.0 {
                consistencyComponent = 0.0
            } else {
                consistencyComponent = 100.0 - (deviation - 15.0) * (100.0 / 75.0)
            }
        } else {
            consistencyComponent = 50.0
        }

        let total = durationScore * 0.4 + qualityScore * 0.4 + consistencyComponent * 0.2
        return max(0, min(100, Int(total.rounded())))
    }

    // MARK: - Computed: todayEntry

    var todayEntry: SleepTrackerEntry? {
        let cal = Calendar.current
        let today = Date()
        return entries.first { entry in
            guard let d = entry.calendarDate else { return false }
            return cal.isDate(d, inSameDayAs: today)
        }
    }

    // MARK: - Computed: currentStreak

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()

        if todayEntry == nil {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let hasEntry = entries.contains { entry in
                guard let d = entry.calendarDate else { return false }
                return cal.isDate(d, inSameDayAs: checkDate)
            }
            if hasEntry {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Computed: weeklyAverage

    var weeklyAverage: Double {
        let weekData = entriesInPast(days: 7)
        guard !weekData.isEmpty else { return 0 }
        let total = weekData.reduce(0.0) { $0 + $1.sleepDuration }
        return total / Double(weekData.count)
    }

    // MARK: - Computed: sleepDebt

    var sleepDebt: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var totalDebt = 0.0

        for dayOffset in 0..<14 {
            guard let checkDate = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayEntry = entries.first { entry in
                guard let d = entry.calendarDate else { return false }
                return cal.isDate(d, inSameDayAs: checkDate)
            }

            if let entry = dayEntry {
                let deficit = sleepGoal - entry.sleepDuration
                if deficit > 0 {
                    totalDebt += deficit
                }
            } else {
                totalDebt += sleepGoal
            }
        }

        return max(0, totalDebt)
    }

    // MARK: - Computed: consistencyScore

    var consistencyScore: Int {
        let thirtyDayData = entriesInPast(days: 30)
        guard thirtyDayData.count >= 5 else { return 0 }

        let minutes = thirtyDayData.map { $0.bedTimeMinutesFromMidnight }
        let mean = minutes.reduce(0, +) / Double(minutes.count)
        let variance = minutes.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(minutes.count)
        let stdev = sqrt(variance)

        if stdev <= 15.0 { return 100 }
        if stdev >= 90.0 { return 0 }
        return Int((100.0 - (stdev - 15.0) * (100.0 / 75.0)).rounded())
    }

    // MARK: - Computed: averageBedtime

    var averageBedtime: Date? {
        let thirtyDayData = entriesInPast(days: 30)
        guard !thirtyDayData.isEmpty else { return nil }

        let minutes = thirtyDayData.map { $0.bedTimeMinutesFromMidnight }
        let avgMinutes = minutes.reduce(0, +) / Double(minutes.count)

        var totalMinutes = avgMinutes
        if totalMinutes < 0 { totalMinutes += 1440.0 }
        let hour = Int(totalMinutes) / 60
        let minute = Int(totalMinutes) % 60

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }

    var averageBedtimeFormatted: String? {
        guard let avg = averageBedtime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: avg)
    }

    // MARK: - Computed: weekEntries

    var weekEntries: [SleepTrackerEntry] {
        entriesInPast(days: 7).sorted {
            ($0.calendarDate ?? .distantPast) < ($1.calendarDate ?? .distantPast)
        }
    }

    // MARK: - Computed: moodDistribution

    var moodDistribution: [WakeMood: Int] {
        let thirtyDayData = entriesInPast(days: 30)
        var dist: [WakeMood: Int] = [:]
        for mood in WakeMood.allCases {
            dist[mood] = 0
        }
        for entry in thirtyDayData {
            dist[entry.wakeMood, default: 0] += 1
        }
        return dist
    }

    // MARK: - Computed: weekdayVsWeekendAverage

    var weekdayVsWeekendAverage: (weekday: Double, weekend: Double) {
        let thirtyDayData = entriesInPast(days: 30)

        let weekdayEntries = thirtyDayData.filter { !$0.isWeekend }
        let weekendEntries = thirtyDayData.filter { $0.isWeekend }

        let weekdayAvg = weekdayEntries.isEmpty ? 0.0
            : weekdayEntries.reduce(0.0) { $0 + $1.sleepDuration } / Double(weekdayEntries.count)
        let weekendAvg = weekendEntries.isEmpty ? 0.0
            : weekendEntries.reduce(0.0) { $0 + $1.sleepDuration } / Double(weekendEntries.count)

        return (weekday: weekdayAvg, weekend: weekendAvg)
    }

    // MARK: - WeekDay Timeline (for WeekView chart)

    var weekDayTimeline: [WeekDayEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var timeline: [WeekDayEntry] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            let label = dayFormatter.string(from: date)

            let matchingEntry = entries.first { entry in
                guard let d = entry.calendarDate else { return false }
                return cal.isDate(d, inSameDayAs: date)
            }

            timeline.append(WeekDayEntry(date: date, dayLabel: label, entry: matchingEntry))
        }

        return timeline
    }

    // MARK: - Average Wake Time

    var averageWakeTime: Date? {
        let thirtyDayData = entriesInPast(days: 30)
        guard !thirtyDayData.isEmpty else { return nil }

        let cal = Calendar.current
        let minutes = thirtyDayData.map { entry -> Double in
            let hour = cal.component(.hour, from: entry.wakeTime)
            let minute = cal.component(.minute, from: entry.wakeTime)
            return Double(hour * 60 + minute)
        }
        let avgMinutes = minutes.reduce(0, +) / Double(minutes.count)
        let hour = Int(avgMinutes) / 60
        let minute = Int(avgMinutes) % 60

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return cal.date(from: components)
    }

    var averageWakeTimeFormatted: String? {
        guard let avg = averageWakeTime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: avg)
    }

    // MARK: - Previous Week Average (for trend delta)

    var previousWeekAverage: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: today),
              let oneWeekAgo = cal.date(byAdding: .day, value: -7, to: today) else { return 0 }

        let prevWeekEntries = entries.filter { entry in
            guard let d = entry.calendarDate else { return false }
            return d >= twoWeeksAgo && d < oneWeekAgo
        }
        guard !prevWeekEntries.isEmpty else { return 0 }
        return prevWeekEntries.reduce(0.0) { $0 + $1.sleepDuration } / Double(prevWeekEntries.count)
    }

    var weeklyAverageDelta: Double {
        weeklyAverage - previousWeekAverage
    }

    // MARK: - Quality Trend (7-day moving average)

    var qualityTrend: Double {
        let weekData = entriesInPast(days: 7)
        guard !weekData.isEmpty else { return 0 }
        return weekData.reduce(0.0) { $0 + Double($1.qualityRating) } / Double(weekData.count)
    }

    // MARK: - Chart Data

    var durationChartData: [ChartDataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var points: [ChartDataPoint] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        for dayOffset in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let label = dayFormatter.string(from: date)
            let dayEntry = entries.first { entry in
                guard let d = entry.calendarDate else { return false }
                return cal.isDate(d, inSameDayAs: date)
            }
            points.append(ChartDataPoint(label: label, value: dayEntry?.sleepDuration ?? 0))
        }
        return points
    }

    var thirtyDayDurationChartData: [ChartDataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var points: [ChartDataPoint] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "M/d"

        for dayOffset in (0..<30).reversed() {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let label = dayFormatter.string(from: date)
            let dayEntry = entries.first { entry in
                guard let d = entry.calendarDate else { return false }
                return cal.isDate(d, inSameDayAs: date)
            }
            points.append(ChartDataPoint(label: label, value: dayEntry?.sleepDuration ?? 0))
        }
        return points
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // 1. Sleep debt alert
        let debt = sleepDebt
        if debt > 5.0 {
            let debtFormatted = String(format: "%.1f", debt)
            result.append(ModuleInsight(
                type: .warning,
                title: "Sleep Debt Alert",
                message: "You have \(debtFormatted)h of sleep debt over the past 2 weeks. Consider an earlier bedtime tonight."
            ))
        }

        // 2. Weekend oversleep
        let wdwe = weekdayVsWeekendAverage
        let oversleepMinutes = (wdwe.weekend - wdwe.weekday) * 60.0
        if oversleepMinutes > 30 {
            let mins = Int(oversleepMinutes.rounded())
            result.append(ModuleInsight(
                type: .trend,
                title: "Weekend Oversleep",
                message: "You sleep \(mins) min more on weekends vs weekdays."
            ))
        }

        // 3. Quality-duration correlation
        let thirtyDayData = entriesInPast(days: 30)
        if thirtyDayData.count >= 7 {
            let r = pearsonCorrelation(
                xs: thirtyDayData.map { $0.sleepDuration },
                ys: thirtyDayData.map { Double($0.qualityRating) }
            )
            if r > 0.5 {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Quality-Duration Link",
                    message: "Longer sleep strongly improves your quality rating."
                ))
            }
        }

        // 4. Best bedtime window
        if thirtyDayData.count >= 7 {
            let bestWindow = bestBedtimeWindow(entries: thirtyDayData)
            if let window = bestWindow {
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Best Bedtime Window",
                    message: "Your best sleep quality happens when you go to bed between \(window.start) and \(window.end)."
                ))
            }
        }

        // 5. Mood-duration link
        if thirtyDayData.count >= 7 {
            let bestBucket = bestMoodDurationBucket(entries: thirtyDayData)
            if let bucket = bestBucket {
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Mood & Duration",
                    message: "You feel most energized or refreshed when sleeping \(bucket.displayName)."
                ))
            }
        }

        // 6. Consistency streak
        let consStreak = bedtimeConsistencyStreak
        if consStreak >= 7 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Consistent Schedule",
                message: "You kept a consistent bedtime for \(consStreak) days in a row!"
            ))
        }

        // 7. Logging streak
        if currentStreak >= 7 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Logging Streak",
                message: "You've logged sleep for \(currentStreak) consecutive days! Keep it up."
            ))
        }

        // 8. Irregular schedule warning
        if consistencyScore < 40 && thirtyDayData.count >= 5 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Irregular Schedule",
                message: "Your bedtime varies significantly. A regular schedule can improve sleep quality."
            ))
        }

        return result
    }

    // MARK: - Sleep Debt Level

    var sleepDebtLevel: SleepDebtLevel {
        SleepDebtLevel.from(debtHours: sleepDebt)
    }

    // MARK: - Sleep Score Grade (for today)

    var todaySleepScoreGrade: SleepScoreGrade? {
        guard let entry = todayEntry else { return nil }
        return SleepScoreGrade.from(score: sleepScore(for: entry))
    }

    var consistencyGrade: ConsistencyGrade {
        ConsistencyGrade.from(score: consistencyScore)
    }

    // MARK: - Duration Distribution (for TrendsView)

    var durationDistribution: [DurationBucket: Int] {
        let thirtyDayData = entriesInPast(days: 30)
        var dist: [DurationBucket: Int] = [:]
        for bucket in DurationBucket.allCases {
            dist[bucket] = 0
        }
        for entry in thirtyDayData {
            let bucket = DurationBucket.bucket(for: entry.sleepDuration)
            dist[bucket, default: 0] += 1
        }
        return dist
    }

    // MARK: - Bedtime Consistency Standard Deviation (minutes)

    var bedtimeStandardDeviation: Double {
        let thirtyDayData = entriesInPast(days: 30)
        guard thirtyDayData.count >= 2 else { return 0 }

        let minutes = thirtyDayData.map { $0.bedTimeMinutesFromMidnight }
        let mean = minutes.reduce(0, +) / Double(minutes.count)
        let variance = minutes.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(minutes.count)
        return sqrt(variance)
    }

    // MARK: - Private Helpers

    private func entriesInPast(days: Int) -> [SleepTrackerEntry] {
        let cal = Calendar.current
        let today = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: today) else { return [] }

        return entries.filter { entry in
            guard let d = entry.calendarDate else { return false }
            return d >= startDate && d <= today
        }
    }

    private var averageBedtimeMinutesFromMidnight: Double? {
        let thirtyDayData = entriesInPast(days: 30)
        guard !thirtyDayData.isEmpty else { return nil }
        let minutes = thirtyDayData.map { $0.bedTimeMinutesFromMidnight }
        return minutes.reduce(0, +) / Double(minutes.count)
    }

    private func pearsonCorrelation(xs: [Double], ys: [Double]) -> Double {
        guard xs.count == ys.count, xs.count >= 3 else { return 0 }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var numerator = 0.0
        var denomX = 0.0
        var denomY = 0.0

        for i in 0..<xs.count {
            let dx = xs[i] - meanX
            let dy = ys[i] - meanY
            numerator += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }

        let denom = sqrt(denomX * denomY)
        guard denom > 0 else { return 0 }
        return numerator / denom
    }

    private func bestBedtimeWindow(entries: [SleepTrackerEntry]) -> (start: String, end: String)? {
        // Group entries by bedtime hour and find the hour range with highest average quality
        let cal = Calendar.current
        var hourQualities: [Int: [Int]] = [:]

        for entry in entries {
            let hour = cal.component(.hour, from: entry.bedTime)
            hourQualities[hour, default: []].append(entry.qualityRating)
        }

        guard !hourQualities.isEmpty else { return nil }

        let hourAverages = hourQualities.mapValues { ratings -> Double in
            Double(ratings.reduce(0, +)) / Double(ratings.count)
        }

        guard let bestHour = hourAverages.max(by: { $0.value < $1.value })?.key else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "ha"

        var startComponents = DateComponents()
        startComponents.hour = bestHour
        var endComponents = DateComponents()
        endComponents.hour = (bestHour + 1) % 24

        guard let startDate = cal.date(from: startComponents),
              let endDate = cal.date(from: endComponents) else { return nil }

        return (start: formatter.string(from: startDate).lowercased(),
                end: formatter.string(from: endDate).lowercased())
    }

    private func bestMoodDurationBucket(entries: [SleepTrackerEntry]) -> DurationBucket? {
        var bucketPositiveMoodCounts: [DurationBucket: Int] = [:]
        var bucketTotalCounts: [DurationBucket: Int] = [:]

        for entry in entries {
            let bucket = DurationBucket.bucket(for: entry.sleepDuration)
            bucketTotalCounts[bucket, default: 0] += 1
            if entry.wakeMood == .energized || entry.wakeMood == .refreshed {
                bucketPositiveMoodCounts[bucket, default: 0] += 1
            }
        }

        // Find bucket with highest ratio of positive moods
        var bestBucket: DurationBucket?
        var bestRatio = 0.0

        for (bucket, total) in bucketTotalCounts where total >= 2 {
            let positive = Double(bucketPositiveMoodCounts[bucket] ?? 0)
            let ratio = positive / Double(total)
            if ratio > bestRatio {
                bestRatio = ratio
                bestBucket = bucket
            }
        }

        return bestRatio > 0 ? bestBucket : nil
    }

    private var bedtimeConsistencyStreak: Int {
        guard let avgMinutes = averageBedtimeMinutesFromMidnight else { return 0 }

        let sorted = entries
            .compactMap { entry -> (date: Date, minutes: Double)? in
                guard let d = entry.calendarDate else { return nil }
                return (date: d, minutes: entry.bedTimeMinutesFromMidnight)
            }
            .sorted { $0.date > $1.date }

        var streak = 0
        for item in sorted {
            if abs(item.minutes - avgMinutes) <= 30 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}