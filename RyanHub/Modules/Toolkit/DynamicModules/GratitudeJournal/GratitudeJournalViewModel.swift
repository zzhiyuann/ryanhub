import Foundation

// MARK: - Supporting Types

struct DailyMoodPoint: Identifiable {
    let id: String
    let date: Date
    let averageMood: Double
}

struct GratitudeInsight: Identifiable {
    enum InsightType { case trend, achievement, suggestion, warning }
    let id: String = UUID().uuidString
    let type: InsightType
    let title: String
    let message: String
}

// MARK: - ViewModel

@Observable
@MainActor
final class GratitudeJournalViewModel {

    var entries: [GratitudeJournalEntry] = []
    var isLoading = false
    var errorMessage: String?

    let dailyGoal: Int = 3
    private let moduleId = "gratitudeJournal"

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

        guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([GratitudeJournalEntry].self, from: data)
            entries = decoded
            UserDefaults.standard.set(data, forKey: "dynamic_module_\(moduleId)_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(gratitudeText: String, category: GratitudeCategory, intensity: Int, mood: MoodLevel, isHighlight: Bool) async {
        let entry = GratitudeJournalEntry(
            gratitudeText: gratitudeText,
            category: category,
            intensity: intensity,
            mood: mood,
            isHighlight: isHighlight
        )
        guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data/add") else { return }
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

    func deleteEntry(_ entry: GratitudeJournalEntry) async {
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

    // MARK: - Date Helpers

    private func parsedDate(_ entry: GratitudeJournalEntry) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: entry.date)
    }

    private func calendarDay(from entry: GratitudeJournalEntry) -> Date? {
        guard let d = parsedDate(entry) else { return nil }
        return Calendar.current.startOfDay(for: d)
    }

    private func entriesInRange(days: Int) -> [GratitudeJournalEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { parsedDate($0).map { $0 >= cutoff } ?? false }
    }

    // MARK: - Computed Properties

    var todayEntries: [GratitudeJournalEntry] {
        entries
            .filter { e in parsedDate(e).map { Calendar.current.isDateInToday($0) } ?? false }
            .sorted { (parsedDate($0) ?? Date.distantPast) < (parsedDate($1) ?? Date.distantPast) }
    }

    var todayCount: Int { todayEntries.count }

    var dailyGoalProgress: Double {
        min(Double(todayCount) / Double(dailyGoal), 1.0)
    }

    var currentStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daySet = Set(entries.compactMap { calendarDay(from: $0) })

        let todayMet = (entries.filter { e in parsedDate(e).map { cal.isDateInToday($0) } ?? false }.count) >= dailyGoal
        var streak = 0
        var check = todayMet ? today : cal.date(byAdding: .day, value: -1, to: today)!

        while true {
            let count = entries.filter { e in
                guard let d = calendarDay(from: e) else { return false }
                return d == check
            }.count
            if count >= dailyGoal {
                streak += 1
                check = cal.date(byAdding: .day, value: -1, to: check)!
            } else {
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        let cal = Calendar.current
        let dayMap = Dictionary(grouping: entries, by: { calendarDay(from: $0) ?? Date.distantPast })
        let completeDays = dayMap
            .filter { $0.value.count >= dailyGoal }
            .keys
            .sorted()

        var longest = 0
        var current = 0
        var prev: Date? = nil

        for day in completeDays {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p) == day {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prev = day
        }
        return longest
    }

    var weeklyAverage: Double {
        let week = entriesInRange(days: 7)
        return Double(week.count) / 7.0
    }

    var weeklyTrend: Double {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeekStart = cal.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeek = entries.filter { e in
            guard let d = parsedDate(e) else { return false }
            return d >= weekStart && d <= now
        }
        let lastWeek = entries.filter { e in
            guard let d = parsedDate(e) else { return false }
            return d >= twoWeekStart && d < weekStart
        }

        let thisAvg = Double(thisWeek.count) / 7.0
        let lastAvg = Double(lastWeek.count) / 7.0
        guard lastAvg > 0 else { return thisAvg > 0 ? 1.0 : 0.0 }
        return (thisAvg - lastAvg) / lastAvg
    }

    var categoryDistribution: [(GratitudeCategory, Int)] {
        let month = entriesInRange(days: 30)
        var counts: [GratitudeCategory: Int] = [:]
        for e in month { counts[e.category, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var categoryDiversityScore: Double {
        let dist = categoryDistribution
        let total = dist.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        let entropy = dist.reduce(0.0) { acc, pair in
            let p = Double(pair.1) / Double(total)
            return p > 0 ? acc - p * log(p) : acc
        }
        let maxEntropy = log(Double(GratitudeCategory.allCases.count))
        return maxEntropy > 0 ? min(entropy / maxEntropy, 1.0) : 0
    }

    private func moodValue(_ mood: MoodLevel) -> Double {
        switch mood {
        case .amazing: return 5
        case .good: return 4
        case .okay: return 3
        case .low: return 2
        case .rough: return 1
        }
    }

    var averageMood: Double {
        let week = entriesInRange(days: 7)
        guard !week.isEmpty else { return 0 }
        return week.reduce(0.0) { $0 + moodValue($1.mood) } / Double(week.count)
    }

    var moodTrend: [DailyMoodPoint] {
        let cal = Calendar.current
        let month = entriesInRange(days: 30)
        let grouped = Dictionary(grouping: month) { e -> Date in
            (parsedDate(e).map { cal.startOfDay(for: $0) }) ?? cal.startOfDay(for: Date())
        }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return grouped.sorted { $0.key < $1.key }.map { (day, dayEntries) in
            let avg = dayEntries.reduce(0.0) { $0 + moodValue($1.mood) } / Double(dayEntries.count)
            return DailyMoodPoint(id: df.string(from: day), date: day, averageMood: avg)
        }
    }

    var averageIntensity: Double {
        let month = entriesInRange(days: 30)
        guard !month.isEmpty else { return 0 }
        return month.reduce(0.0) { $0 + Double($1.intensity) } / Double(month.count)
    }

    var completionRate: Double {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let month = entries.filter { parsedDate($0).map { $0 >= cutoff } ?? false }
        let grouped = Dictionary(grouping: month) { e -> Date in
            (parsedDate(e).map { cal.startOfDay(for: $0) }) ?? cal.startOfDay(for: Date())
        }
        let completeDays = grouped.filter { $0.value.count >= dailyGoal }.count
        return Double(completeDays) / 30.0
    }

    var totalEntries: Int { entries.count }

    var totalDaysJournaled: Int {
        Set(entries.compactMap { calendarDay(from: $0) }).count
    }

    var highlights: [GratitudeJournalEntry] {
        entriesInRange(days: 7).filter { $0.isHighlight }
    }

    var streakHistory: [(startDate: Date, length: Int)] {
        let cal = Calendar.current
        let dayMap = Dictionary(grouping: entries, by: { calendarDay(from: $0) ?? Date.distantPast })
        let completeDays = dayMap
            .filter { $0.value.count >= dailyGoal }
            .keys
            .sorted()

        var result: [(startDate: Date, length: Int)] = []
        var streakStart: Date? = nil
        var streakLen = 0
        var prev: Date? = nil

        for day in completeDays {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p) == day {
                streakLen += 1
            } else {
                if let s = streakStart, streakLen >= 3 {
                    result.append((startDate: s, length: streakLen))
                }
                streakStart = day
                streakLen = 1
            }
            prev = day
        }
        if let s = streakStart, streakLen >= 3 {
            result.append((startDate: s, length: streakLen))
        }
        return result
    }

    // MARK: - Insights

    var insights: [GratitudeInsight] {
        var result: [GratitudeInsight] = []

        // streak_milestone
        let milestones = [7, 14, 30, 60, 100, 365]
        for milestone in milestones {
            if currentStreak <= milestone && milestone - currentStreak <= 2 && currentStreak > 0 {
                let daysLeft = milestone - currentStreak
                let msg = daysLeft == 0
                    ? "You hit a \(milestone)-day streak! Amazing dedication."
                    : "Just \(daysLeft) day\(daysLeft == 1 ? "" : "s") away from a \(milestone)-day streak. Keep going!"
                result.append(GratitudeInsight(type: .achievement, title: "Streak Milestone Ahead", message: msg))
                break
            }
        }

        // longest_streak_beat
        if currentStreak > longestStreak && currentStreak > 0 {
            result.append(GratitudeInsight(type: .achievement, title: "New Personal Best!", message: "You've beaten your longest streak with \(currentStreak) days. This is your all-time record!"))
        }

        // category_concentration
        let dist = categoryDistribution
        let total = dist.reduce(0) { $0 + $1.1 }
        if let top = dist.first, total > 0, Double(top.1) / Double(total) > 0.6 {
            result.append(GratitudeInsight(type: .suggestion, title: "Expand Your Gratitude", message: "Over 60% of your entries are about \(top.0.displayName). Try exploring gratitude in other areas of life."))
        }

        // diversity_nudge
        if categoryDiversityScore < 0.4 {
            let represented = Set(dist.map { $0.0 })
            let missing = GratitudeCategory.allCases.filter { !represented.contains($0) }
            if let suggestion = missing.first {
                result.append(GratitudeInsight(type: .suggestion, title: "Try a New Category", message: "You haven't journaled about \(suggestion.displayName) recently. What are you grateful for there?"))
            }
        }

        // mood_correlation
        let twoWeeks = entriesInRange(days: 14)
        if twoWeeks.count >= 7 {
            let cal = Calendar.current
            let grouped = Dictionary(grouping: twoWeeks) { e -> Date in
                (parsedDate(e).map { cal.startOfDay(for: $0) }) ?? cal.startOfDay(for: Date())
            }
            let pairs = grouped.values.map { dayEntries -> (Double, Double) in
                let count = Double(dayEntries.count)
                let mood = dayEntries.reduce(0.0) { $0 + moodValue($1.mood) } / count
                return (count, mood)
            }
            if pairs.count >= 5 {
                let counts = pairs.map { $0.0 }
                let moods = pairs.map { $0.1 }
                let meanC = counts.reduce(0, +) / Double(counts.count)
                let meanM = moods.reduce(0, +) / Double(moods.count)
                let num = zip(counts, moods).reduce(0.0) { $0 + ($1.0 - meanC) * ($1.1 - meanM) }
                let denC = sqrt(counts.reduce(0.0) { $0 + pow($1 - meanC, 2) })
                let denM = sqrt(moods.reduce(0.0) { $0 + pow($1 - meanM, 2) })
                let corr = (denC * denM) > 0 ? num / (denC * denM) : 0
                if corr > 0.3 {
                    result.append(GratitudeInsight(type: .trend, title: "Gratitude Lifts Your Mood", message: "Days with more gratitude entries correlate with better mood. Keep journaling — it's working!"))
                }
            }
        }

        // consistency_pattern — find weakest day of week
        let cal = Calendar.current
        var dayCompletions: [Int: [Bool]] = [:]
        let cutoff30 = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30 = entries.filter { parsedDate($0).map { $0 >= cutoff30 } ?? false }
        let dayGrouped = Dictionary(grouping: last30) { e -> Date in
            (parsedDate(e).map { cal.startOfDay(for: $0) }) ?? cal.startOfDay(for: Date())
        }
        for (day, dayEntries) in dayGrouped {
            let weekday = cal.component(.weekday, from: day)
            dayCompletions[weekday, default: []].append(dayEntries.count >= dailyGoal)
        }
        if let weakest = dayCompletions.min(by: { a, b in
            let rateA = a.value.filter { $0 }.count
            let rateB = b.value.filter { $0 }.count
            return rateA < rateB
        }) {
            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let dayName = dayNames[safe: weakest.key] ?? "that day"
            let rate = weakest.value.filter { $0 }.count
            if rate < weakest.value.count {
                result.append(GratitudeInsight(type: .suggestion, title: "Set a \(dayName) Reminder", message: "\(dayName)s tend to be your toughest day for journaling. Consider setting a reminder to keep your streak alive."))
            }
        }

        // gratitude_growth
        let thisMonth = entriesInRange(days: 30)
        let lastMonthCutoff = cal.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let lastMonthStart = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let lastMonth = entries.filter { e in
            guard let d = parsedDate(e) else { return false }
            return d >= lastMonthCutoff && d < lastMonthStart
        }
        let thisAvgIntensity = thisMonth.isEmpty ? 0.0 : thisMonth.reduce(0.0) { $0 + Double($1.intensity) } / Double(thisMonth.count)
        let lastAvgIntensity = lastMonth.isEmpty ? 0.0 : lastMonth.reduce(0.0) { $0 + Double($1.intensity) } / Double(lastMonth.count)
        if lastAvgIntensity > 0 && thisAvgIntensity > lastAvgIntensity {
            result.append(GratitudeInsight(type: .achievement, title: "Deeper Gratitude", message: String(format: "Your average gratitude intensity this month (%.1f) is higher than last month (%.1f). You're feeling more deeply thankful!", thisAvgIntensity, lastAvgIntensity)))
        }

        // highlight_reflection — weekends
        let weekday = cal.component(.weekday, from: Date())
        if weekday == 1 || weekday == 7 {
            let monthHighlights = entries.filter { e in
                guard let d = parsedDate(e) else { return false }
                return d >= cutoff30 && e.isHighlight
            }
            if monthHighlights.count >= 3 {
                result.append(GratitudeInsight(type: .trend, title: "Weekend Reflection", message: "You have \(monthHighlights.count) highlights from this month. Take a moment to re-read them and relive the gratitude."))
            }
        }

        return result
    }

    // MARK: - Chart Data

    var chartData: [ChartDataPoint] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let cutoff = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let week = entries.filter { parsedDate($0).map { $0 >= cutoff } ?? false }
        let grouped = Dictionary(grouping: week) { e -> Date in
            (parsedDate(e).map { cal.startOfDay(for: $0) }) ?? cal.startOfDay(for: Date())
        }
        return grouped.sorted { $0.key < $1.key }.map { (day, dayEntries) in
            ChartDataPoint(label: df.string(from: day), value: Double(dayEntries.count))
        }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}