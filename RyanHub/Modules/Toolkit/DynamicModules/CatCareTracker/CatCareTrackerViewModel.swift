import Foundation

@Observable
@MainActor
final class CatCareTrackerViewModel {

    // MARK: - State

    var entries: [CatCareTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

    let dailyGoal: Int = 3

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
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    var todayEntries: [CatCareTrackerEntry] {
        entries.filter { Calendar.current.isDateInToday($0.parsedDate) }
    }

    var weekEntries: [CatCareTrackerEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.parsedDate >= cutoff }
    }

    var last30DaysEntries: [CatCareTrackerEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return entries.filter { $0.parsedDate >= cutoff }
    }

    // MARK: - Feeding Computed Properties

    var todayFeedingCount: Int {
        todayEntries.filter { $0.eventType == .feeding }.count
    }

    var lastFeedingTime: Date? {
        entries.filter { $0.eventType == .feeding }
               .sorted { $0.parsedDate > $1.parsedDate }
               .first?.parsedDate
    }

    var timeSinceLastFeeding: String {
        guard let last = lastFeedingTime else { return "No feedings yet" }
        let elapsed = Date().timeIntervalSince(last)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        if hours == 0 {
            return "\(minutes)m ago"
        } else if minutes == 0 {
            return "\(hours)h ago"
        } else {
            return "\(hours)h \(minutes)m ago"
        }
    }

    var timeSinceLastFeedingIsAlert: Bool {
        guard let last = lastFeedingTime else { return false }
        let elapsed = Date().timeIntervalSince(last)
        return elapsed > 8 * 3600
    }

    var feedingStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check today first — if today has no feeding, start from yesterday
        let todayFeedings = entries.filter {
            $0.eventType == .feeding && calendar.isDate($0.parsedDate, inSameDayAs: checkDate)
        }
        if todayFeedings.isEmpty {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let dayFeedings = entries.filter {
                $0.eventType == .feeding && calendar.isDate($0.parsedDate, inSameDayAs: checkDate)
            }
            if dayFeedings.isEmpty { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    var averageDailyFeedings: Double {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let recent = entries.filter { $0.eventType == .feeding && $0.parsedDate >= sevenDaysAgo }
        return Double(recent.count) / 7.0
    }

    var averageDailyFeedingsPriorWeek: Double {
        let calendar = Calendar.current
        guard
            let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: Date()),
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())
        else { return 0 }
        let prior = entries.filter {
            $0.eventType == .feeding && $0.parsedDate >= fourteenDaysAgo && $0.parsedDate < sevenDaysAgo
        }
        return Double(prior.count) / 7.0
    }

    var feedingTrendDirection: String {
        let delta = averageDailyFeedings - averageDailyFeedingsPriorWeek
        if delta > 0.2 { return "↑" }
        if delta < -0.2 { return "↓" }
        return "→"
    }

    var goalProgress: Double {
        min(Double(todayFeedingCount) / Double(dailyGoal), 1.0)
    }

    // MARK: - Weight Computed Properties

    var weightEntries: [CatCareTrackerEntry] {
        entries.filter { $0.eventType == .weightCheck && $0.catWeight > 0 }
               .sorted { $0.parsedDate < $1.parsedDate }
    }

    var latestWeight: Double? {
        weightEntries.last?.catWeight
    }

    var weightTrend: Double? {
        guard weightEntries.count >= 2 else { return nil }
        let last = weightEntries[weightEntries.count - 1].catWeight
        let prev = weightEntries[weightEntries.count - 2].catWeight
        return last - prev
    }

    var weightHistory: [(Date, Double)] {
        weightEntries.map { ($0.parsedDate, $0.catWeight) }
    }

    // MARK: - Vet Computed Properties

    var vetEntries: [CatCareTrackerEntry] {
        entries.filter { $0.eventType == .vetVisit }
               .sorted { $0.parsedDate > $1.parsedDate }
    }

    var daysSinceLastVetVisit: Int? {
        guard let lastVet = vetEntries.first?.parsedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastVet, to: Date()).day
    }

    var totalVetCostsThisYear: Double {
        let year = Calendar.current.component(.year, from: Date())
        return entries.filter {
            $0.eventType == .vetVisit &&
            Calendar.current.component(.year, from: $0.parsedDate) == year
        }.reduce(0) { $0 + $1.cost }
    }

    // MARK: - Dashboard Computed Properties

    var hasUnresolvedSymptomToday: Bool {
        todayEntries.contains { $0.eventType == .symptom }
    }

    var latestWeightFormatted: String {
        guard let w = latestWeight else { return "—" }
        return String(format: "%.1f lbs", w)
    }

    var feedingProgress: Double { goalProgress }

    var dailyFeedingGoal: Int { dailyGoal }

    func todayCountForFeedType(_ feedType: FeedType) -> Int {
        todayEntries.filter { $0.eventType == .feeding && $0.feedType == feedType }.count
    }

    var currentStreak: Int { feedingStreak }

    var longestStreak: Int {
        let calendar = Calendar.current
        let feedingDates = Set(
            entries.filter { $0.eventType == .feeding }
                .map { calendar.startOfDay(for: $0.parsedDate) }
        )
        guard !feedingDates.isEmpty else { return 0 }
        let sorted = feedingDates.sorted()
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            if calendar.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    var hasEntryToday: Bool { !todayEntries.isEmpty }

    var recentSymptomCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.eventType == .symptom && $0.parsedDate >= cutoff }.count
    }

    var daysSinceLastVetVisitText: String {
        guard let days = daysSinceLastVetVisit else { return "—" }
        return "\(days)d"
    }

    var insights: [ModuleInsight] { moduleInsights }

    // MARK: - Chart Data

    var weeklyFeedingData: [DailyCount] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset -> DailyCount in
            let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date())) ?? Date()
            let count = entries.filter {
                $0.eventType == .feeding && calendar.isDate($0.parsedDate, inSameDayAs: date)
            }.count
            return DailyCount(date: date, count: count)
        }
    }

    var feedTypeDistribution: [FeedType: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = entries.filter { $0.eventType == .feeding && $0.parsedDate >= cutoff }
        var dist: [FeedType: Int] = [:]
        for entry in recent {
            dist[entry.feedType, default: 0] += 1
        }
        return dist
    }

    var symptomFrequency: [SymptomType: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = entries.filter { $0.eventType == .symptom && $0.parsedDate >= cutoff }
        var freq: [SymptomType: Int] = [:]
        for entry in recent {
            freq[entry.symptomType, default: 0] += 1
        }
        return freq
    }

    var moodDistribution: [CatMood: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = entries.filter { $0.parsedDate >= cutoff }
        var dist: [CatMood: Int] = [:]
        for entry in recent {
            dist[entry.catMood, default: 0] += 1
        }
        return dist
    }

    // MARK: - Feeding Consistency Score

    var feedingConsistencyScore: Double {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let recentFeedings = entries.filter { $0.eventType == .feeding && $0.parsedDate >= sevenDaysAgo }
        guard recentFeedings.count >= 2 else { return recentFeedings.isEmpty ? 0 : 50 }

        let hours = recentFeedings.map { Double($0.hourOfDay) }
        let mean = hours.reduce(0, +) / Double(hours.count)
        let variance = hours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hours.count)
        let stdDev = sqrt(variance)

        // stdDev of 0 = perfect score 100, stdDev of 6+ hours = score 0
        let score = max(0, min(100, 100 - (stdDev / 6.0) * 100))
        return score
    }

    // MARK: - Insights

    var healthInsights: [String] {
        var insights: [String] = []

        // 1. Feeding gap alert (daytime 6am-10pm)
        if let last = lastFeedingTime {
            let elapsed = Date().timeIntervalSince(last) / 3600
            let hour = Calendar.current.component(.hour, from: Date())
            if elapsed > 10 && hour >= 6 && hour <= 22 {
                let hrs = Int(elapsed)
                insights.append("⚠️ Feeding gap: \(hrs) hours since last feeding. Consider feeding soon.")
            }
        } else {
            insights.append("⚠️ No feedings logged yet. Start tracking meals to monitor your cat's health.")
        }

        // 2. Weight change alert
        if let trend = weightTrend {
            if abs(trend) > 0.5 {
                let direction = trend > 0 ? "gained" : "lost"
                insights.append("⚠️ Weight alert: Your cat has \(direction) \(String(format: "%.1f", abs(trend))) lbs since the last check.")
            }
        }

        // 3. Consecutive weight trend (3+ in same direction)
        if weightEntries.count >= 3 {
            let last3 = weightEntries.suffix(3)
            let weights = last3.map { $0.catWeight }
            if weights[0] < weights[1] && weights[1] < weights[2] {
                insights.append("📈 Weight trend: Your cat's weight has been increasing over the last 3 checks.")
            } else if weights[0] > weights[1] && weights[1] > weights[2] {
                insights.append("📉 Weight trend: Your cat's weight has been decreasing over the last 3 checks.")
            }
        }

        // 4. Vet reminder
        if let days = daysSinceLastVetVisit {
            if days > 365 {
                insights.append("🚨 Urgent: It's been \(days) days since the last vet visit. Please schedule a checkup immediately.")
            } else if days > 180 {
                insights.append("🏥 Vet reminder: It's been \(days) days since the last vet visit. Consider scheduling a routine checkup.")
            }
        } else {
            insights.append("🏥 No vet visits recorded. Regular checkups are recommended for your cat's health.")
        }

        // 5. Symptom cluster warning
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSymptoms = entries.filter { $0.eventType == .symptom && $0.parsedDate >= sevenDaysAgo }
        if recentSymptoms.count >= 3 {
            insights.append("⚠️ Symptom cluster: \(recentSymptoms.count) symptoms logged in the past 7 days. A vet visit is recommended.")
        }

        // 6. Mood shift detection
        let sevenDaysMoods = entries.filter { $0.parsedDate >= sevenDaysAgo }
        let prevSevenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let prevWeekMoods = entries.filter { $0.parsedDate >= prevSevenDaysAgo && $0.parsedDate < sevenDaysAgo }

        if !sevenDaysMoods.isEmpty && !prevWeekMoods.isEmpty {
            let recentPositiveRatio = Double(sevenDaysMoods.filter { $0.catMood.isPositive }.count) / Double(sevenDaysMoods.count)
            let prevPositiveRatio = Double(prevWeekMoods.filter { $0.catMood.isPositive }.count) / Double(prevWeekMoods.count)
            if prevPositiveRatio >= 0.5 && recentPositiveRatio < 0.4 {
                insights.append("😟 Mood shift detected: Your cat's mood has shifted toward negative states this week. Monitor closely.")
            }
        }

        // 7. Feeding consistency praise
        if feedingConsistencyScore > 80 {
            insights.append("🌟 Great consistency! Your cat is being fed on a very regular schedule (score: \(Int(feedingConsistencyScore))/100).")
        }

        // 8. Annual vet cost summary
        if totalVetCostsThisYear > 0 {
            let visitCount = vetEntries.filter {
                Calendar.current.component(.year, from: $0.parsedDate) == Calendar.current.component(.year, from: Date())
            }.count
            let avgCost = visitCount > 0 ? totalVetCostsThisYear / Double(visitCount) : 0
            insights.append("💰 Vet costs this year: $\(String(format: "%.2f", totalVetCostsThisYear)) across \(visitCount) visit(s) (avg $\(String(format: "%.2f", avgCost))/visit).")
        }

        return insights
    }

    // MARK: - ModuleInsight Array

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Feeding gap
        if let last = lastFeedingTime {
            let elapsed = Date().timeIntervalSince(last) / 3600
            let hour = Calendar.current.component(.hour, from: Date())
            if elapsed > 10 && hour >= 6 && hour <= 22 {
                result.append(ModuleInsight(
                    type: .warning,
                    title: "Feeding Gap",
                    message: "\(Int(elapsed)) hours since last meal. Time to feed your cat!"
                ))
            }
        }

        // Weight alert
        if let trend = weightTrend, abs(trend) > 0.5 {
            let dir = trend > 0 ? "gained" : "lost"
            result.append(ModuleInsight(
                type: .warning,
                title: "Weight Change",
                message: "Your cat has \(dir) \(String(format: "%.1f", abs(trend))) lbs since last check."
            ))
        }

        // Vet reminder
        if let days = daysSinceLastVetVisit, days > 180 {
            result.append(ModuleInsight(
                type: days > 365 ? .warning : .suggestion,
                title: days > 365 ? "Urgent Vet Visit" : "Vet Reminder",
                message: "Last visit was \(days) days ago. \(days > 365 ? "Please schedule immediately." : "Consider booking a checkup.")"
            ))
        }

        // Symptom cluster
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSymptomCount = entries.filter { $0.eventType == .symptom && $0.parsedDate >= sevenDaysAgo }.count
        if recentSymptomCount >= 3 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Symptom Cluster",
                message: "\(recentSymptomCount) symptoms in 7 days. A vet visit is recommended."
            ))
        }

        // Consistency praise
        if feedingConsistencyScore > 80 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Consistent Feeding",
                message: "Excellent feeding schedule consistency! Score: \(Int(feedingConsistencyScore))/100."
            ))
        }

        // Feeding trend
        if averageDailyFeedings > 0 {
            result.append(ModuleInsight(
                type: .trend,
                title: "Weekly Feeding Average",
                message: "\(String(format: "%.1f", averageDailyFeedings)) meals/day this week \(feedingTrendDirection) vs last week."
            ))
        }

        // Streak achievement
        if feedingStreak >= 7 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Feeding Streak",
                message: "\(feedingStreak)-day streak of daily feedings! Keep it up."
            ))
        }

        return result
    }

    // MARK: - Chart Data Points

    var weeklyFeedingChartData: [ChartDataPoint] {
        weeklyFeedingData.map { daily in
            let label = daily.date.formatted(.dateTime.weekday(.abbreviated))
            return ChartDataPoint(label: label, value: Double(daily.count))
        }
    }

    var weightHistoryChartData: [ChartDataPoint] {
        weightHistory.map { (date, weight) in
            let label = date.formatted(.dateTime.month(.abbreviated).day())
            return ChartDataPoint(label: label, value: weight)
        }
    }

    var feedTypeChartData: [ChartDataPoint] {
        feedTypeDistribution.map { feedType, count in
            ChartDataPoint(label: feedType.displayName, value: Double(count))
        }.sorted { $0.value > $1.value }
    }

    var moodChartData: [ChartDataPoint] {
        moodDistribution.map { mood, count in
            ChartDataPoint(label: mood.displayName, value: Double(count))
        }.sorted { $0.value > $1.value }
    }
}