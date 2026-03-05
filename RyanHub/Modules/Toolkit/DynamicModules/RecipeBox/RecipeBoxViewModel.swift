import Foundation

@Observable
@MainActor
final class RecipeBoxViewModel {

    // MARK: - State

    var entries: [RecipeBoxEntry] = []
    var isLoading = false
    var errorMessage: String?

    let weeklyGoal: Int = 2

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

        guard let url = URL(string: "\(bridgeBaseURL)/modules/recipeBox/data") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([RecipeBoxEntry].self, from: data)
            entries = decoded
            if let cached = try? JSONEncoder().encode(decoded) {
                UserDefaults.standard.set(cached, forKey: "dynamic_module_recipeBox_cache")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: RecipeBoxEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/recipeBox/data/add") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: RecipeBoxEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/recipeBox/data?id=\(entry.id)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: request)
            entries.removeAll { $0.id == entry.id }
            if let cached = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(cached, forKey: "dynamic_module_recipeBox_cache")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed: Counts

    var totalRecipes: Int {
        entries.count
    }

    var favoriteRecipes: [RecipeBoxEntry] {
        entries.filter { $0.isFavorite }.sorted { $0.rating > $1.rating }
    }

    var recipesAddedThisWeek: Int {
        let cal = Calendar.current
        return entries.filter {
            guard let d = $0.dateValue else { return false }
            return cal.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    var recipesAddedThisMonth: Int {
        let cal = Calendar.current
        return entries.filter {
            guard let d = $0.dateValue else { return false }
            return cal.isDate(d, equalTo: Date(), toGranularity: .month)
        }.count
    }

    var totalTimesCooked: Int {
        entries.reduce(0) { $0 + $1.timesCooked }
    }

    /// Approximated as sum of timesCooked for recipes added this month.
    var timesCookedThisMonth: Int {
        let cal = Calendar.current
        return entries.filter {
            guard let d = $0.dateValue else { return false }
            return cal.isDate(d, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.timesCooked }
    }

    // MARK: - Computed: Averages

    var averageRating: Double {
        let rated = entries.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return rated.reduce(0.0) { $0 + $1.rating } / Double(rated.count)
    }

    var averageTotalTime: Int {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.totalTimeMinutes } / entries.count
    }

    // MARK: - Computed: Streak

    var cookingStreak: Int {
        let cal = Calendar.current

        let currentWeekActive = entries.contains {
            guard let d = $0.dateValue else { return false }
            return cal.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        }
        guard currentWeekActive else { return 0 }

        var streak = 1
        for weekOffset in 1..<52 {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) else { break }
            let active = entries.contains {
                guard let d = $0.dateValue else { return false }
                return cal.isDate(d, equalTo: weekDate, toGranularity: .weekOfYear)
            }
            if active { streak += 1 } else { break }
        }
        return streak
    }

    // MARK: - Computed: Distributions

    var cuisineDistribution: [(String, Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.cuisine.displayName, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var categoryDistribution: [(String, Int)] {
        var counts: [String: Int] = [:]
        for category in MealCategory.allCases {
            counts[category.displayName] = 0
        }
        for entry in entries {
            counts[entry.category.displayName, default: 0] += 1
        }
        return MealCategory.allCases.map { ($0.displayName, counts[$0.displayName] ?? 0) }
    }

    var difficultyBreakdown: [(String, Int)] {
        var counts: [String: Int] = [:]
        for level in DifficultyLevel.allCases {
            counts[level.displayName] = 0
        }
        for entry in entries {
            counts[entry.difficulty.displayName, default: 0] += 1
        }
        return DifficultyLevel.allCases.sorted { $0.sortOrder < $1.sortOrder }
            .map { ($0.displayName, counts[$0.displayName] ?? 0) }
    }

    var mostCookedRecipes: [(String, Int)] {
        entries
            .filter { $0.timesCooked > 0 }
            .sorted { $0.timesCooked > $1.timesCooked }
            .prefix(5)
            .map { ($0.name, $0.timesCooked) }
    }

    // MARK: - Computed: Trends

    /// Recipes added per week for the last 8 weeks, oldest first.
    var weeklyAdditionTrend: [Double] {
        let cal = Calendar.current
        return (0..<8).reversed().map { weekOffset -> Double in
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) else { return 0 }
            let count = entries.filter {
                guard let d = $0.dateValue else { return false }
                return cal.isDate(d, equalTo: weekDate, toGranularity: .weekOfYear)
            }.count
            return Double(count)
        }
    }

    var goalProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(Double(recipesAddedThisWeek) / Double(weeklyGoal), 1.0)
    }

    var quickRecipes: [RecipeBoxEntry] {
        entries.filter { $0.isQuickRecipe }.sorted { $0.totalTimeMinutes < $1.totalTimeMinutes }
    }

    // MARK: - Chart Data

    var cuisineChartData: [ChartDataPoint] {
        cuisineDistribution.map { ChartDataPoint(label: $0.0, value: Double($0.1)) }
    }

    var categoryChartData: [ChartDataPoint] {
        categoryDistribution.map { ChartDataPoint(label: $0.0, value: Double($0.1)) }
    }

    var difficultyChartData: [ChartDataPoint] {
        difficultyBreakdown.map { ChartDataPoint(label: $0.0, value: Double($0.1)) }
    }

    var weeklyTrendChartData: [ChartDataPoint] {
        let trend = weeklyAdditionTrend
        return trend.enumerated().map { index, value in
            let label = index == trend.count - 1 ? "Now" : "W-\(trend.count - 1 - index)"
            return ChartDataPoint(label: label, value: value)
        }
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Cuisine diversity
        let usedCuisines = Set(entries.map { $0.cuisine }).count
        let totalCuisines = CuisineType.allCases.count
        let diversityPct = totalCuisines > 0 ? Int(Double(usedCuisines) / Double(totalCuisines) * 100) : 0
        if diversityPct >= 50 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Cuisine Explorer",
                message: "You've tried \(usedCuisines) of \(totalCuisines) cuisine types (\(diversityPct)%). Great variety!"
            ))
        } else if totalRecipes > 0 {
            let missing = totalCuisines - usedCuisines
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Expand Your Horizons",
                message: "You've explored \(usedCuisines) of \(totalCuisines) cuisines. Try adding recipes from \(missing) more to diversify."
            ))
        }

        // Most cooked recipe
        if let top = mostCookedRecipes.first {
            result.append(ModuleInsight(
                type: .trend,
                title: "Your Go-To Recipe",
                message: "\"\(top.0)\" is your most-cooked dish at \(top.1) time\(top.1 == 1 ? "" : "s"). A true household staple!"
            ))
        }

        // Neglected favorites
        let neglected = entries.filter { $0.isFavorite && $0.timesCooked == 0 }
        if !neglected.isEmpty {
            let firstName = neglected.first?.name ?? "one of them"
            result.append(ModuleInsight(
                type: .warning,
                title: "Uncook'd Favorites",
                message: "You have \(neglected.count) favorited recipe\(neglected.count == 1 ? "" : "s") you've never made. Start with \"\(firstName)\"!"
            ))
        }

        // Quick meal ratio
        if totalRecipes > 5 {
            let quickPct = Int(Double(quickRecipes.count) / Double(totalRecipes) * 100)
            if quickPct < 20 {
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Busy Night Prep",
                    message: "Only \(quickPct)% of your recipes take under 30 minutes. Add more quick meals for hectic weeknights."
                ))
            } else if quickPct >= 40 {
                result.append(ModuleInsight(
                    type: .achievement,
                    title: "Quick Cook Ready",
                    message: "\(quickPct)% of your recipes are under 30 minutes. You're always prepared for a fast meal."
                ))
            }
        }

        // Collection growth rate
        let trend = weeklyAdditionTrend
        let recentAvg = trend.suffix(4).reduce(0, +) / 4
        let olderAvg = trend.prefix(4).reduce(0, +) / 4
        if recentAvg > olderAvg + 0.5 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Collection Momentum",
                message: "You've been adding \(String(format: "%.1f", recentAvg)) recipes/week lately — faster than before. Keep it up!"
            ))
        } else if totalRecipes > 0 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Weekly Goal",
                message: "You're at \(recipesAddedThisWeek) of \(weeklyGoal) new recipe\(weeklyGoal == 1 ? "" : "s") this week. \(recipesAddedThisWeek >= weeklyGoal ? "Goal reached!" : "Keep exploring!")"
            ))
        }

        // Average rating quality
        if averageRating >= 8.0 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "High Standards",
                message: "Your average recipe rating is \(String(format: "%.1f", averageRating))/10. You curate quality recipes!"
            ))
        } else if averageRating > 0 && averageRating < 5.0 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Refine Your Collection",
                message: "Average rating is \(String(format: "%.1f", averageRating))/10. Consider removing recipes that didn't work out."
            ))
        }

        // Difficulty progression
        if totalRecipes >= 5 {
            let hardCount = entries.filter { $0.difficulty == .hard }.count
            let hardPct = Int(Double(hardCount) / Double(totalRecipes) * 100)
            if hardPct >= 20 {
                result.append(ModuleInsight(
                    type: .achievement,
                    title: "Skill Builder",
                    message: "\(hardPct)% of your recipes are advanced difficulty. You're pushing your culinary limits!"
                ))
            }
        }

        return result
    }
}