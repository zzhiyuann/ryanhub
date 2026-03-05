import Foundation

@Observable
@MainActor
final class MoodJournalViewModel {
    var entries: [MoodJournalEntry] = []
    var isLoading = false
    var errorMessage: String?

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let url = URL(string: "\(bridgeBaseURL)/modules/moodJournal/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([MoodJournalEntry].self, from: data)
            entries = decoded.sorted { ($0.calendarDate ?? .distantPast) > ($1.calendarDate ?? .distantPast) }
            UserDefaults.standard.set(data, forKey: "dynamic_module_moodJournal_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: MoodJournalEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/moodJournal/data/add") else { return }
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

    func deleteEntry(_ entry: MoodJournalEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/moodJournal/data?id=\(entry.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Buckets

    private var cal: Calendar { Calendar.current }

    var todayEntries: [MoodJournalEntry] {
        entries.filter { $0.calendarDate.map { cal.isDateInToday($0) } ?? false }
    }

    private var weekEntries: [MoodJournalEntry] {
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return entries.filter { ($0.calendarDate ?? .distantPast) >= weekStart }
    }

    private var previousWeekEntries: [MoodJournalEntry] {
        guard
            let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start,
            let prevWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
        else { return [] }
        return entries.filter {
            guard let d = $0.calendarDate else { return false }
            return d >= prevWeekStart && d < thisWeekStart
        }
    }

    private var monthEntries: [MoodJournalEntry] {
        guard let monthStart = cal.dateInterval(of: .month, for: Date())?.start else { return [] }
        return entries.filter { ($0.calendarDate ?? .distantPast) >= monthStart }
    }

    private var last7DaysEntries: [MoodJournalEntry] {
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .day, value: -6, to: today) else { return [] }
        return entries.filter { ($0.calendarDate ?? .distantPast) >= cutoff }
    }

    // MARK: - Computed Properties

    var todayLatestMood: Int? {
        todayEntries
            .sorted { ($0.calendarDate ?? .distantPast) > ($1.calendarDate ?? .distantPast) }
            .first?.moodRating
    }

    var todayEntryCount: Int { todayEntries.count }

    var weeklyMoodAverage: Double { average(weekEntries.map { Double($0.moodRating) }) }

    var previousWeekMoodAverage: Double { average(previousWeekEntries.map { Double($0.moodRating) }) }

    var moodTrendDirection: TrendDirection {
        let diff = weeklyMoodAverage - previousWeekMoodAverage
        if diff >= 0.5 { return .up }
        if diff <= -0.5 { return .down }
        return .stable
    }

    var currentStreak: Int {
        let activeDayKeys = Set(entries.compactMap { $0.calendarDate.map { dayKey($0) } })
        var streak = 0
        var check = cal.startOfDay(for: Date())
        while activeDayKeys.contains(dayKey(check)) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    var longestStreak: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let sortedKeys = Set(entries.compactMap { $0.calendarDate.map { dayKey($0) } })
            .compactMap { fmt.date(from: $0) }
            .sorted()
        guard !sortedKeys.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<sortedKeys.count {
            let diff = cal.dateComponents([.day], from: sortedKeys[i - 1], to: sortedKeys[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    var weeklyMoodChartData: [(date: Date, avgMood: Double)] {
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<7).compactMap { offset -> (date: Date, avgMood: Double)? in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart),
                  day <= Date() else { return nil }
            let dayMoods = entries
                .filter { $0.calendarDate.map { cal.isDate($0, inSameDayAs: day) } ?? false }
                .map { Double($0.moodRating) }
            return (date: day, avgMood: average(dayMoods))
        }
    }

    var monthlyMoodChartData: [(date: Date, avgMood: Double)] {
        guard let monthInterval = cal.dateInterval(of: .month, for: Date()) else { return [] }
        let daysInMonth = cal.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
        return (0..<daysInMonth).compactMap { offset -> (date: Date, avgMood: Double)? in
            guard let day = cal.date(byAdding: .day, value: offset, to: monthInterval.start),
                  day <= Date() else { return nil }
            let dayMoods = entries
                .filter { $0.calendarDate.map { cal.isDate($0, inSameDayAs: day) } ?? false }
                .map { Double($0.moodRating) }
            return (date: day, avgMood: average(dayMoods))
        }
    }

    var moodDistribution: [Int: Int] {
        var dist: [Int: Int] = Dictionary(uniqueKeysWithValues: (1...10).map { ($0, 0) })
        for entry in entries { dist[entry.moodRating, default: 0] += 1 }
        return dist
    }

    var averageMoodByActivity: [(activity: MoodActivity, avgMood: Double)] {
        var groups: [MoodActivity: [Double]] = [:]
        for e in entries { groups[e.activity, default: []].append(Double(e.moodRating)) }
        return groups
            .map { (activity: $0.key, avgMood: average($0.value)) }
            .sorted { $0.avgMood > $1.avgMood }
    }

    var averageMoodByDayOfWeek: [(weekday: Int, avgMood: Double)] {
        var groups: [Int: [Double]] = [:]
        for e in entries {
            guard let d = e.calendarDate else { continue }
            let wd = cal.component(.weekday, from: d)
            groups[wd, default: []].append(Double(e.moodRating))
        }
        return groups
            .map { (weekday: $0.key, avgMood: average($0.value)) }
            .sorted { $0.weekday < $1.weekday }
    }

    var averageMoodBySocialContext: [(context: SocialContext, avgMood: Double)] {
        var groups: [SocialContext: [Double]] = [:]
        for e in entries { groups[e.socialContext, default: []].append(Double(e.moodRating)) }
        return groups
            .map { (context: $0.key, avgMood: average($0.value)) }
            .sorted { $0.avgMood > $1.avgMood }
    }

    var energyMoodCorrelation: Double {
        guard entries.count > 1 else { return 0 }
        let xs = entries.map { Double($0.energyLevel) }
        let ys = entries.map { Double($0.moodRating) }
        let n = Double(entries.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        let numerator = zip(xs, ys).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
        let denomX = sqrt(xs.map { ($0 - meanX) * ($0 - meanX) }.reduce(0, +))
        let denomY = sqrt(ys.map { ($0 - meanY) * ($0 - meanY) }.reduce(0, +))
        guard denomX > 0, denomY > 0 else { return 0 }
        return numerator / (denomX * denomY)
    }

    var moodVolatility: Double {
        let moods = last7DaysEntries.map { Double($0.moodRating) }
        guard moods.count > 1 else { return 0 }
        let mean = moods.reduce(0, +) / Double(moods.count)
        let variance = moods.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(moods.count)
        return sqrt(variance)
    }

    var goalProgress: Double { todayEntries.isEmpty ? 0.0 : 1.0 }

    var totalEntries: Int { entries.count }

    var isActiveToday: Bool { !todayEntries.isEmpty }

    var averageMood: Double { average(entries.map { Double($0.moodRating) }) }

    var averageEnergy: Double { average(entries.map { Double($0.energyLevel) }) }

    var averageAnxiety: Double { average(entries.map { Double($0.anxietyLevel) }) }

    var trendDirection: TrendDirection { moodTrendDirection }

    var weeklyChartData: [ChartDataPoint] { weeklyChartPoints }

    var mostFrequentActivity: MoodActivity? {
        let counts = Dictionary(grouping: entries, by: { $0.activity })
        return counts.max(by: { $0.value.count < $1.value.count })?.key
    }

    var mostFrequentContext: SocialContext? {
        let counts = Dictionary(grouping: entries, by: { $0.socialContext })
        return counts.max(by: { $0.value.count < $1.value.count })?.key
    }

    var heatmapData: [Date: Double] {
        var data: [Date: Double] = [:]
        for entry in entries {
            if let d = entry.calendarDate {
                let day = cal.startOfDay(for: d)
                data[day, default: 0] += Double(entry.moodRating)
            }
        }
        return data
    }

    var calendarData: [Date: Double] { heatmapData }

    var insights: [MoodInsight] { insightsList }

    var insightsList: [MoodInsight] {
        var insights: [MoodInsight] = []

        // Best activity
        if let best = averageMoodByActivity.first, best.avgMood > 0 {
            insights.append(MoodInsight(
                title: "Best Activity: \(best.activity.displayName)",
                body: "You feel happiest when doing \(best.activity.displayName) (avg \(fmt1(best.avgMood))/10) — try to do it more often.",
                icon: best.activity.icon
            ))
        }

        // Worst day of week
        if let worst = averageMoodByDayOfWeek.min(by: { $0.avgMood < $1.avgMood }), !averageMoodByDayOfWeek.isEmpty {
            let name = weekdayName(for: worst.weekday)
            insights.append(MoodInsight(
                title: "Watch Out for \(name)s",
                body: "Your mood tends to dip on \(name)s (avg \(fmt1(worst.avgMood))/10) — consider planning something enjoyable.",
                icon: "calendar.badge.exclamationmark"
            ))
        }

        // Energy-mood link
        if abs(energyMoodCorrelation) > 0.3 {
            let pct = Int(abs(energyMoodCorrelation) * 100)
            insights.append(MoodInsight(
                title: "Energy Boosts Your Mood",
                body: "Higher energy days correlate with \(pct)% better mood — prioritize sleep and movement.",
                icon: "bolt.heart.fill"
            ))
        }

        // Social insight vs alone
        let aloneAvg = averageMoodBySocialContext.first(where: { $0.context == .alone })?.avgMood ?? 0
        if let bestSocial = averageMoodBySocialContext.first(where: { $0.context != .alone }),
           bestSocial.avgMood - aloneAvg >= 0.5 {
            let diff = fmt1(bestSocial.avgMood - aloneAvg)
            insights.append(MoodInsight(
                title: "Social Mood Boost",
                body: "You rate \(diff) points higher when with \(bestSocial.context.displayName) vs alone.",
                icon: bestSocial.context.icon
            ))
        }

        // Streak milestone or progress
        let milestones = [7, 14, 30, 60, 90, 180, 365]
        if milestones.contains(currentStreak) {
            insights.append(MoodInsight(
                title: "\(currentStreak)-Day Streak! 🎉",
                body: "Amazing! \(currentStreak)-day journaling streak — consistency builds self-awareness.",
                icon: "flame.fill"
            ))
        } else if currentStreak > 0 {
            insights.append(MoodInsight(
                title: "\(currentStreak)-Day Streak",
                body: "You've logged mood for \(currentStreak) consecutive days. Keep building the habit!",
                icon: "flame.fill"
            ))
        }

        // Volatility warning
        if moodVolatility > 2.5 {
            insights.append(MoodInsight(
                title: "High Mood Variability",
                body: "Your mood varied by \(fmt1(moodVolatility)) points this week — high variability may signal stress.",
                icon: "exclamationmark.triangle.fill",
                isAlert: true
            ))
        }

        // Trend alert (>1.5 point week-over-week shift)
        let weekDelta = weeklyMoodAverage - previousWeekMoodAverage
        if abs(weekDelta) > 1.5 && weeklyMoodAverage > 0 && previousWeekMoodAverage > 0 {
            let direction = weekDelta > 0 ? "up" : "down"
            insights.append(MoodInsight(
                title: weekDelta > 0 ? "Mood Improving" : "Mood Declining",
                body: "Your mood has been trending \(direction) over the past 2 weeks (\(String(format: "%+.1f", weekDelta)) point change).",
                icon: weekDelta > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                isAlert: weekDelta < 0
            ))
        }

        // Anxiety pattern
        var anxietyByWeekday: [Int: [Double]] = [:]
        for e in entries {
            guard let d = e.calendarDate else { continue }
            let wd = cal.component(.weekday, from: d)
            anxietyByWeekday[wd, default: []].append(Double(e.anxietyLevel))
        }
        if let highAnxDay = anxietyByWeekday
            .map({ (weekday: $0.key, avg: average($0.value)) })
            .max(by: { $0.avg < $1.avg }),
           highAnxDay.avg >= 6 {
            let overallAvg = average(entries.map { Double($0.moodRating) })
            let moodOnDay = averageMoodByDayOfWeek.first(where: { $0.weekday == highAnxDay.weekday })?.avgMood ?? overallAvg
            let drop = overallAvg - moodOnDay
            if drop > 0.5 {
                let name = weekdayName(for: highAnxDay.weekday)
                insights.append(MoodInsight(
                    title: "Anxiety Pattern on \(name)s",
                    body: "Your anxiety spikes on \(name)s — your mood averages \(fmt1(drop)) points lower on high-anxiety days.",
                    icon: "brain.head.profile",
                    isAlert: true
                ))
            }
        }

        return insights
    }

    // MARK: - Chart Points for ModuleChartView

    var weeklyChartPoints: [ChartDataPoint] {
        weeklyMoodChartData.map { ChartDataPoint(label: shortDayLabel($0.date), value: $0.avgMood) }
    }

    var monthlyChartPoints: [ChartDataPoint] {
        monthlyMoodChartData.map { ChartDataPoint(label: dayOfMonthLabel($0.date), value: $0.avgMood) }
    }

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []
        if let best = averageMoodByActivity.first, best.avgMood > 0 {
            result.append(ModuleInsight(type: .suggestion, title: "Best Activity",
                message: "\(best.activity.displayName) correlates with your highest mood (avg \(fmt1(best.avgMood))/10)."))
        }
        if currentStreak >= 7 {
            result.append(ModuleInsight(type: .achievement, title: "\(currentStreak)-Day Streak",
                message: "You've journaled for \(currentStreak) days in a row."))
        }
        if moodVolatility > 2.5 {
            result.append(ModuleInsight(type: .warning, title: "High Variability",
                message: "Mood swung \(fmt1(moodVolatility)) pts this week — may indicate stress."))
        }
        let delta = weeklyMoodAverage - previousWeekMoodAverage
        if abs(delta) >= 0.5 && weeklyMoodAverage > 0 && previousWeekMoodAverage > 0 {
            result.append(ModuleInsight(type: .trend,
                title: delta >= 0.5 ? "Mood Improving" : "Mood Declining",
                message: "Weekly average shifted \(String(format: "%+.1f", delta)) pts vs last week."))
        }
        return result
    }

    // MARK: - Private Helpers

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = cal.weekdaySymbols
        guard weekday >= 1, weekday <= 7 else { return "that day" }
        return symbols[weekday - 1]
    }

    private func shortDayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayOfMonthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func fmt1(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}