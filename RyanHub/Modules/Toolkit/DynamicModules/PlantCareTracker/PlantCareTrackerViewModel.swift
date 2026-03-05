import Foundation

@Observable
@MainActor
final class PlantCareTrackerViewModel {
    var entries: [PlantCareTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var dailyGoal: Int = 3

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

        guard let url = URL(string: "\(bridgeBaseURL)/modules/plantCareTracker/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            entries = try JSONDecoder().decode([PlantCareTrackerEntry].self, from: data)
            UserDefaults.standard.set(data, forKey: "dynamic_module_plantCareTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: PlantCareTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/plantCareTracker/data/add") else { return }
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

    func deleteEntry(_ entry: PlantCareTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/plantCareTracker/data?id=\(entry.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    var todayEntries: [PlantCareTrackerEntry] {
        entries.filter { Calendar.current.isDate($0.parsedDate, inSameDayAs: Date()) }
    }

    var weekEntries: [PlantCareTrackerEntry] {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        return entries.filter { $0.parsedDate >= weekStart && $0.parsedDate < weekEnd }
    }

    var last30DaysEntries: [PlantCareTrackerEntry] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return [] }
        return entries.filter { $0.parsedDate >= cutoff }
    }

    // MARK: - Computed Properties

    var todaysCareCount: Int {
        todayEntries.count
    }

    var uniquePlantsToday: Int {
        Set(todayEntries.map { $0.plantName }).count
    }

    var totalUniquePlants: Int {
        Set(entries.map { $0.plantName }).count
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()

        let todayHasEntries = entries.contains { cal.isDate($0.parsedDate, inSameDayAs: checkDate) }
        if !todayHasEntries {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let hasEntries = entries.contains { cal.isDate($0.parsedDate, inSameDayAs: checkDate) }
            guard hasEntries else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var weeklyCareSessions: Int {
        weekEntries.count
    }

    var weeklyTrendPercent: Double {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let prevWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart),
              let prevWeekEnd = cal.date(byAdding: .day, value: 7, to: prevWeekStart) else { return 0 }
        let prevCount = entries.filter { $0.parsedDate >= prevWeekStart && $0.parsedDate < prevWeekEnd }.count
        let current = Double(weeklyCareSessions)
        guard prevCount > 0 else { return current > 0 ? 100.0 : 0.0 }
        return ((current - Double(prevCount)) / Double(prevCount)) * 100.0
    }

    var averageHealthScore: Double {
        let recent = last30DaysEntries
        guard !recent.isEmpty else { return 0 }
        return Double(recent.map { $0.healthScore }.reduce(0, +)) / Double(recent.count)
    }

    var healthTrend: Double {
        let cal = Calendar.current
        let now = Date()
        guard let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart) else { return 0 }

        func avg(_ es: [PlantCareTrackerEntry]) -> Double {
            guard !es.isEmpty else { return 0 }
            return Double(es.map { $0.healthScore }.reduce(0, +)) / Double(es.count)
        }

        let thisMonth = entries.filter { $0.parsedDate >= thisMonthStart }
        let lastMonth = entries.filter { $0.parsedDate >= lastMonthStart && $0.parsedDate < thisMonthStart }
        return avg(thisMonth) - avg(lastMonth)
    }

    var careTypeBreakdown: [(String, Int)] {
        var counts: [String: Int] = [:]
        for entry in last30DaysEntries {
            counts[entry.careType.displayName, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var mostActivePlant: String? {
        var counts: [String: Int] = [:]
        for entry in last30DaysEntries {
            counts[entry.plantName, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var plantsDueForWater: [String] {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -7, to: Date()) else { return [] }

        var lastWaterDate: [String: Date] = [:]
        for entry in entries where entry.careType == .water {
            let current = lastWaterDate[entry.plantName]
            if current == nil || entry.parsedDate > current! {
                lastWaterDate[entry.plantName] = entry.parsedDate
            }
        }

        return lastWaterDate
            .filter { $0.value < cutoff }
            .map { $0.key }
            .sorted()
    }

    var calendarData: [Date: Double] {
        var map: [Date: Double] = [:]
        for entry in entries {
            let day = Calendar.current.startOfDay(for: entry.parsedDate)
            map[day, default: 0] += 1
        }
        return map
    }

    var goalProgress: Double {
        min(Double(todaysCareCount) / Double(max(1, dailyGoal)), 1.0)
    }

    var weeklyChartData: [(String, Int)] {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return []
        }
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let count = entries.filter { cal.isDate($0.parsedDate, inSameDayAs: day) }.count
            return (dayLabels[offset], count)
        }
    }

    var monthlyHealthChartData: [(String, Double)] {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return [] }

        return (0..<4).compactMap { weekOffset in
            guard let wStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: monthStart),
                  let wEnd = cal.date(byAdding: .day, value: 7, to: wStart) else { return nil }
            let weekBatch = entries.filter { $0.parsedDate >= wStart && $0.parsedDate < wEnd }
            let avg: Double = weekBatch.isEmpty
                ? 0
                : Double(weekBatch.map { $0.healthScore }.reduce(0, +)) / Double(weekBatch.count)
            return ("W\(weekOffset + 1)", avg)
        }
    }

    var locationDistribution: [(String, Int)] {
        var plantsByLocation: [String: Set<String>] = [:]
        for entry in entries {
            plantsByLocation[entry.location.displayName, default: []].insert(entry.plantName)
        }
        return plantsByLocation.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    var todayInsights: [String] {
        var insights: [String] = []
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let uniquePlants = Set(entries.map { $0.plantName })

        // Thirsty plants
        if !plantsDueForWater.isEmpty {
            insights.append("💧 Thirsty: \(plantsDueForWater.joined(separator: ", ")) — not watered in 7+ days.")
        }

        // Declining health (last 3 scores trending down)
        for plant in uniquePlants.sorted() {
            let plantEntries = entries
                .filter { $0.plantName == plant }
                .sorted { $0.parsedDate > $1.parsedDate }
            if plantEntries.count >= 3 {
                let scores = plantEntries.prefix(3).map { $0.healthScore }
                if scores[0] < scores[1] && scores[1] < scores[2] {
                    insights.append("📉 \(plant) health declining (\(scores[2])→\(scores[1])→\(scores[0])). Check its care routine.")
                }
            }
        }

        // Fertilize reminder (30+ days since last fertilize)
        guard let fertilizeCutoff = cal.date(byAdding: .day, value: -30, to: now) else { return insights }
        for plant in uniquePlants.sorted() {
            let lastFertilize = entries
                .filter { $0.plantName == plant && $0.careType == .fertilize }
                .map { $0.parsedDate }
                .max()
            if lastFertilize == nil || lastFertilize! < fertilizeCutoff {
                insights.append("🌱 \(plant) hasn't been fertilized in 30+ days. Time to feed it!")
            }
        }

        // Streak milestones
        let streak = currentStreak
        let milestones = [7, 14, 30, 60, 90]
        if milestones.contains(streak) {
            insights.append("🏆 \(streak)-day care streak milestone! You're a dedicated plant parent!")
        } else if streak >= 3 {
            insights.append("🔥 \(streak)-day care streak active. Keep the momentum going!")
        }

        // Seasonal watering tip
        if month == 11 || month == 12 || month <= 2 {
            insights.append("❄️ Winter tip: Reduce watering frequency — plants enter dormancy and need less water.")
        } else if month >= 6 && month <= 8 {
            insights.append("☀️ Summer tip: Increase watering — heat causes soil to dry out faster.")
        }

        // Location health alert
        var locationScores: [String: [Int]] = [:]
        for entry in last30DaysEntries {
            locationScores[entry.location.displayName, default: []].append(entry.healthScore)
        }
        let locationAvgs = locationScores.mapValues { Double($0.reduce(0, +)) / Double($0.count) }
        if let worst = locationAvgs.min(by: { $0.value < $1.value }), worst.value < 3.0 {
            insights.append("📍 Plants in \(worst.key) avg \(String(format: "%.1f", worst.value))/5 health. Better light or humidity may help.")
        }

        // Neglect alert
        let avgCare = totalUniquePlants > 0
            ? Double(last30DaysEntries.count) / Double(totalUniquePlants)
            : 0
        if avgCare > 2 {
            for plant in uniquePlants.sorted() {
                let count = last30DaysEntries.filter { $0.plantName == plant }.count
                if count < 2 {
                    insights.append("⚠️ \(plant) has only \(count) care event(s) in 30 days — it may be neglected.")
                }
            }
        }

        // Green thumb score
        let score = computeGreenThumbScore()
        insights.append("🌿 Green Thumb Score this week: \(score)/100")

        return insights
    }

    // MARK: - Private Helpers

    private func computeGreenThumbScore() -> Int {
        let streakScore = min(Double(currentStreak) / 30.0, 1.0) * 30
        let overdueRatio = totalUniquePlants > 0
            ? Double(plantsDueForWater.count) / Double(totalUniquePlants)
            : 0
        let overdueScore = max(0.0, 1.0 - overdueRatio) * 20
        let healthScore = (averageHealthScore / 5.0) * 30
        let targetSessions = Double(dailyGoal * 7)
        let consistencyScore = min(Double(weeklyCareSessions) / max(1, targetSessions), 1.0) * 20
        return Int(min(streakScore + overdueScore + healthScore + consistencyScore, 100))
    }
}