import Foundation

@Observable
@MainActor
final class CatCareTrackerViewModel {

    // MARK: - State

    var entries: [CatCareTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

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

        guard let url = URL(string: "\(bridgeBaseURL)/modules/catCareTracker/data") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([CatCareTrackerEntry].self, from: data)
            entries = decoded.sorted { $0.parsedDate > $1.parsedDate }
            UserDefaults.standard.set(data, forKey: "dynamic_module_catCareTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: CatCareTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/catCareTracker/data/add") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: CatCareTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/catCareTracker/data?id=\(entry.id)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            entries.removeAll { $0.id == entry.id }
            if let data = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(data, forKey: "dynamic_module_catCareTracker_cache")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private func startOfDay(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday
    }

    var todayEntries: [CatCareTrackerEntry] {
        entries.filter { Calendar.current.isDateInToday($0.parsedDate) }
    }

    var weekEntries: [CatCareTrackerEntry] {
        let cutoff = startOfDay(daysAgo: 7)
        return entries.filter { $0.parsedDate >= cutoff }
    }

    var monthEntries: [CatCareTrackerEntry] {
        let cutoff = startOfDay(daysAgo: 30)
        return entries.filter { $0.parsedDate >= cutoff }
    }

    // MARK: - Feeding Computed Properties

    var todayFeedingCount: Int {
        todayEntries.filter { $0.eventType == .feeding && $0.feedType != .water }.count
    }

    var todayFeedingTimes: [Date] {
        todayEntries
            .filter { $0.eventType == .feeding && $0.feedType != .water }
            .map { $0.eventTime }
            .sorted()
    }

    var dailyFeedingGoalProgress: Double {
        let goal = Double(CatCareTrackerEntry.dailyFeedingGoal)
        guard goal > 0 else { return 0 }
        return min(Double(todayFeedingCount) / goal, 1.0)
    }

    var mealCompletionRate: Double {
        let feedings = weekEntries.filter { $0.eventType == .feeding && $0.feedType.countsMeal }
        guard !feedings.isEmpty else { return 0 }
        let eaten = feedings.filter { $0.wasEaten }.count
        return Double(eaten) / Double(feedings.count)
    }

    var feedingConsistencyScore: Double {
        let feedings = entries.filter { $0.eventType == .feeding && $0.feedType.countsMeal }
        guard feedings.count >= 2 else { return feedings.isEmpty ? 0 : 100 }

        let minutesFromMidnight: [Double] = feedings.map {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: $0.eventTime)
            return Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        }

        let mean = minutesFromMidnight.reduce(0, +) / Double(minutesFromMidnight.count)
        let variance = minutesFromMidnight.map { pow($0 - mean, 2) }.reduce(0, +) / Double(minutesFromMidnight.count)
        let stdDev = sqrt(variance)

        // 0 min std dev = score 100; 120 min (2 hrs) std dev = score 0
        return min(max(100.0 - (stdDev / 120.0) * 100.0, 0), 100)
    }

    var weeklyFeedingAverage: Double {
        Double(weekEntries.filter { $0.countsForStreak }.count) / 7.0
    }

    var feedingTrend: String {
        let thisWeekCutoff = startOfDay(daysAgo: 7)
        let lastWeekCutoff = startOfDay(daysAgo: 14)

        let thisWeek = entries.filter { $0.parsedDate >= thisWeekCutoff && $0.countsForStreak }.count
        let lastWeek = entries.filter {
            $0.parsedDate >= lastWeekCutoff && $0.parsedDate < thisWeekCutoff && $0.countsForStreak
        }.count

        let diff = thisWeek - lastWeek
        if diff > 2 { return "increasing" }
        if diff < -2 { return "decreasing" }
        return "stable"
    }

    // MARK: - Weight Computed Properties

    var currentWeight: Int? {
        entries
            .filter { $0.eventType == .weightCheck }
            .sorted { $0.parsedDate > $1.parsedDate }
            .first?
            .weightGrams
    }

    var weightTrend: [(Date, Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return entries
            .filter { $0.eventType == .weightCheck && $0.parsedDate >= cutoff }
            .sorted { $0.parsedDate < $1.parsedDate }
            .map { ($0.parsedDate, $0.weightGrams) }
    }

    var weightChangePercent: Double? {
        let checks = entries
            .filter { $0.eventType == .weightCheck }
            .sorted { $0.parsedDate > $1.parsedDate }
        guard checks.count >= 2 else { return nil }
        let latest = Double(checks[0].weightGrams)
        let previous = Double(checks[1].weightGrams)
        guard previous > 0 else { return nil }
        return (latest - previous) / previous * 100.0
    }

    // MARK: - Vet Visit Computed Properties

    var lastVetVisitDate: Date? {
        entries
            .filter { $0.eventType == .vetVisit }
            .sorted { $0.parsedDate > $1.parsedDate }
            .first?
            .parsedDate
    }

    var daysSinceLastVetVisit: Int? {
        guard let last = lastVetVisitDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }

    // MARK: - Streak

    var careStreak: Int {
        var streak = 0
        var checkDate = startOfToday

        while true {
            let hasFeeding = entries.contains {
                $0.countsForStreak && Calendar.current.isDate($0.parsedDate, inSameDayAs: checkDate)
            }
            guard hasFeeding else { break }
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    // MARK: - Cost

    var monthlyVetCosts: Int {
        entries.filter {
            $0.eventType == .vetVisit &&
            Calendar.current.isDate($0.parsedDate, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.costCents }
    }

    // MARK: - Mood Distribution

    var moodDistribution: [(CatMood, Int)] {
        let cutoff = startOfDay(daysAgo: 30)
        let recent = entries.filter { $0.parsedDate >= cutoff }
        return CatMood.allCases.compactMap { mood in
            let count = recent.filter { $0.mood == mood }.count
            return count > 0 ? (mood, count) : nil
        }
    }

    // MARK: - Overdue Care Alerts

    var overdueCareAlerts: [String] {
        var alerts: [String] = []

        if todayFeedingCount == 0 {
            alerts.append("No feeding logged today — don't forget to feed your cat!")
        }

        if let days = daysSinceLastVetVisit {
            if days > 365 {
                alerts.append("Vet checkup overdue — last visit was \(days) days ago. Annual exams are recommended.")
            }
        } else {
            alerts.append("No vet visit on record. Schedule a wellness checkup soon.")
        }

        let lastFleaTick = entries
            .filter { $0.isFleaTickMedication }
            .sorted { $0.parsedDate > $1.parsedDate }
            .first
        if let last = lastFleaTick {
            let days = Calendar.current.dateComponents([.day], from: last.parsedDate, to: Date()).day ?? 0
            if days > 30 {
                alerts.append("Flea & tick treatment overdue — last applied \(days) days ago.")
            }
        }

        if let change = weightChangePercent, abs(change) > 5 {
            let direction = change > 0 ? "gained" : "lost"
            alerts.append(String(format: "Significant weight change: cat has %@ %.1f%% since last check.", direction, abs(change)))
        }

        return alerts
    }

    // MARK: - Heatmap & Chart Data

    var feedingsByHour: [Int: Int] {
        var result: [Int: Int] = [:]
        for entry in entries where entry.eventType == .feeding && entry.feedType != .water {
            let hour = Calendar.current.component(.hour, from: entry.eventTime)
            result[hour, default: 0] += 1
        }
        return result
    }

    var weeklyChartData: [(String, Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { daysAgo in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday
            let label = formatter.string(from: date)
            let count = entries.filter {
                $0.countsForStreak && Calendar.current.isDate($0.parsedDate, inSameDayAs: date)
            }.count
            return (label, count)
        }
    }

    // MARK: - Chart Data (ModuleChartView)

    var chartData: [ChartDataPoint] {
        weeklyChartData.map { ChartDataPoint(label: $0.0, value: Double($0.1)) }
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Streak achievements
        if careStreak >= 30 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(careStreak)-Day Streak!",
                message: "Incredible consistency — your cat has been fed every day for \(careStreak) days."
            ))
        } else if careStreak >= 7 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(careStreak)-Day Feeding Streak",
                message: "Great job keeping up a daily feeding routine for \(careStreak) days."
            ))
        } else if careStreak == 0 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Streak Reset",
                message: "No qualifying feeding was logged yesterday. Log a meal today to start a new streak."
            ))
        }

        // Feeding trend
        switch feedingTrend {
        case "increasing":
            result.append(ModuleInsight(
                type: .trend,
                title: "Feeding Frequency Increasing",
                message: "This week's feedings are higher than last week's."
            ))
        case "decreasing":
            result.append(ModuleInsight(
                type: .warning,
                title: "Feeding Frequency Dropping",
                message: "Fewer feedings this week than last. Monitor your cat's appetite."
            ))
        default:
            break
        }

        // Meal completion rate
        if mealCompletionRate > 0 && mealCompletionRate < 0.7 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Low Meal Completion",
                message: String(
                    format: "Only %.0f%% of meals were finished this week. Consider a vet check if this persists.",
                    mealCompletionRate * 100
                )
            ))
        } else if mealCompletionRate >= 0.95 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Excellent Appetite",
                message: String(
                    format: "%.0f%% meal completion this week — your cat is eating great!",
                    mealCompletionRate * 100
                )
            ))
        }

        // Feeding consistency
        if feedingConsistencyScore >= 80 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Consistent Feeding Schedule",
                message: String(
                    format: "Feeding consistency score: %.0f/100. Your cat has a reliable routine.",
                    feedingConsistencyScore
                )
            ))
        } else if feedingConsistencyScore < 50 && feedingConsistencyScore > 0 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Irregular Feeding Times",
                message: "Feeding times vary significantly day to day. Cats thrive on a consistent schedule."
            ))
        }

        // Weight change
        if let change = weightChangePercent {
            if abs(change) > 5 {
                let direction = change > 0 ? "increase" : "decrease"
                result.append(ModuleInsight(
                    type: .warning,
                    title: "Significant Weight Change",
                    message: String(
                        format: "A %.1f%% weight %@ detected since the last check. Consult your vet if concerned.",
                        abs(change), direction
                    )
                ))
            }
        }

        // Vet visit reminder
        if let days = daysSinceLastVetVisit {
            if days > 335 {
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Annual Checkup Due",
                    message: "Last vet visit was \(days) days ago. Schedule a wellness exam soon."
                ))
            }
        }

        // Concerning moods
        let concernCount = monthEntries.filter { $0.mood.isConcerning }.count
        let totalCount = monthEntries.count
        if totalCount > 0 && Double(concernCount) / Double(totalCount) > 0.3 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Frequent Concerning Moods",
                message: "Your cat has been lethargic, anxious, or hiding often this month. A vet visit may help."
            ))
        }

        // Overdue flea & tick
        let lastFleaTick = entries
            .filter { $0.isFleaTickMedication }
            .sorted { $0.parsedDate > $1.parsedDate }
            .first
        if let last = lastFleaTick {
            let days = Calendar.current.dateComponents([.day], from: last.parsedDate, to: Date()).day ?? 0
            if days >= 28 {
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Flea & Tick Treatment Due",
                    message: "Last treatment was \(days) days ago. Most monthly treatments should be reapplied now."
                ))
            }
        }

        return result
    }
}