import Foundation

@Observable
@MainActor
final class GroceryListViewModel {

    var entries: [GroceryListEntry] = []
    var isLoading = false
    var errorMessage: String?

    var weeklyBudgetGoal: Double = 100.0
    var estimatedTripsPerWeek: Double = 2.0

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
        guard let url = URL(string: "\(bridgeBaseURL)/modules/groceryList/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([GroceryListEntry].self, from: data)
            entries = decoded
            UserDefaults.standard.set(data, forKey: "dynamic_module_groceryList_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: GroceryListEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/groceryList/data/add") else { return }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: req)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: GroceryListEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/groceryList/data?id=\(entry.id)") else { return }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: req)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePurchased(_ entry: GroceryListEntry) async {
        var updated = entry
        updated.isPurchased.toggle()
        guard let url = URL(string: "\(bridgeBaseURL)/modules/groceryList/data/add") else { return }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(updated)
            let (_, _) = try await URLSession.shared.data(for: req)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var todayEntries: [GroceryListEntry] {
        entries.filter { $0.dateOnly == todayString }
    }

    var weekEntries: [GroceryListEntry] {
        let cal = Calendar.current
        let now = Date()
        return entries.filter {
            guard let d = $0.parsedDate else { return false }
            return cal.isDate(d, equalTo: now, toGranularity: .weekOfYear)
        }
    }

    var lastWeekEntries: [GroceryListEntry] {
        let cal = Calendar.current
        guard let lastWeekDate = cal.date(byAdding: .weekOfYear, value: -1, to: Date()) else { return [] }
        return entries.filter {
            guard let d = $0.parsedDate else { return false }
            return cal.isDate(d, equalTo: lastWeekDate, toGranularity: .weekOfYear)
        }
    }

    // MARK: - Active / Purchased

    var activeItems: [GroceryListEntry] {
        todayEntries
            .filter { !$0.isPurchased }
            .sorted {
                if $0.priority.sortOrder != $1.priority.sortOrder {
                    return $0.priority.sortOrder < $1.priority.sortOrder
                }
                return $0.category.sortOrder < $1.category.sortOrder
            }
    }

    var purchasedItems: [GroceryListEntry] {
        todayEntries
            .filter { $0.isPurchased }
            .sorted {
                ($0.parsedDate ?? Date.distantPast) < ($1.parsedDate ?? Date.distantPast)
            }
    }

    // MARK: - Completion & Totals

    var completionPercentage: Double {
        let total = todayEntries.count
        guard total > 0 else { return 0 }
        return Double(purchasedItems.count) / Double(total) * 100
    }

    var estimatedTotal: Double {
        todayEntries.reduce(0) { $0 + $1.lineTotal }
    }

    var purchasedTotal: Double {
        purchasedItems.reduce(0) { $0 + $1.lineTotal }
    }

    // MARK: - Category Grouping

    var itemsByCategory: [(category: GroceryCategory, items: [GroceryListEntry])] {
        let grouped = Dictionary(grouping: activeItems, by: { $0.category })
        return GroceryCategory.allCases
            .compactMap { cat -> (GroceryCategory, [GroceryListEntry])? in
                guard let items = grouped[cat], !items.isEmpty else { return nil }
                return (cat, items)
            }
    }

    // MARK: - Spending Chart Data

    var weeklySpendingData: [(date: Date, total: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<7).reversed().compactMap { offset -> (Date, Double)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let total = entries.filter {
                guard let d = $0.parsedDate else { return false }
                return cal.isDate(d, inSameDayAs: day)
            }.reduce(0) { $0 + $1.lineTotal }
            return (day, total)
        }
    }

    var monthlySpendingData: [(weekLabel: String, total: Double)] {
        let cal = Calendar.current
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return (0..<4).reversed().map { weekOffset in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekStartDay = cal.dateInterval(of: .weekOfYear, for: weekStart)?.start else {
                return ("", 0.0)
            }
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStartDay) ?? weekStartDay
            let label = f.string(from: weekStartDay)
            let total = entries.filter {
                guard let d = $0.parsedDate else { return false }
                return d >= weekStartDay && d <= weekEnd
            }.reduce(0) { $0 + $1.lineTotal }
            return (label, total)
        }
    }

    // MARK: - Category Spending Breakdown

    var categorySpendingBreakdown: [(category: GroceryCategory, total: Double, percentage: Double)] {
        let grandTotal = entries.reduce(0) { $0 + $1.lineTotal }
        guard grandTotal > 0 else { return [] }
        let grouped = Dictionary(grouping: entries, by: { $0.category })
        return GroceryCategory.allCases.compactMap { cat -> (GroceryCategory, Double, Double)? in
            let total = grouped[cat]?.reduce(0) { $0 + $1.lineTotal } ?? 0
            guard total > 0 else { return nil }
            return (cat, total, total / grandTotal * 100)
        }
        .sorted { $0.1 > $1.1 }
    }

    // MARK: - Frequent Items

    var mostFrequentItems: [(itemName: String, count: Int)] {
        let counts = Dictionary(grouping: entries, by: { $0.itemName.lowercased().trimmingCharacters(in: .whitespaces) })
            .mapValues { $0.count }
        return counts
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Shopping Trips

    var shoppingTrips: [GroceryShoppingTrip] {
        let grouped = Dictionary(grouping: entries, by: { $0.dateOnly })
        return grouped.map { dateStr, items in
            GroceryShoppingTrip(id: dateStr, dateString: dateStr, entries: items)
        }.sorted { $0.dateString > $1.dateString }
    }

    // MARK: - Budget Streak

    var budgetStreak: Int {
        let cal = Calendar.current
        let perTripBudget = weeklyBudgetGoal / estimatedTripsPerWeek
        let trips = shoppingTrips
        var streak = 0
        var checkDate = Date()
        for trip in trips {
            guard let tripDate = trip.parsedDate else { break }
            let dayDiff = cal.dateComponents([.day], from: tripDate, to: checkDate).day ?? 0
            if dayDiff > 7 { break }
            if trip.allEssentialsPurchased && trip.totalSpend <= perTripBudget {
                streak += 1
                checkDate = tripDate
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Average Trip Cost

    var averageTripCost: Double {
        let trips = shoppingTrips
        guard !trips.isEmpty else { return 0 }
        let totalSpend = trips.reduce(0) { $0 + $1.totalSpend }
        return totalSpend / Double(trips.count)
    }

    // MARK: - Spending Trend

    var spendingTrendDirection: String {
        let thisWeekTotal = weekEntries.reduce(0) { $0 + $1.lineTotal }
        let lastWeekTotal = lastWeekEntries.reduce(0) { $0 + $1.lineTotal }
        guard lastWeekTotal > 0 else {
            return thisWeekTotal > 0 ? "up 100%" : "stable"
        }
        let change = (thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100
        if abs(change) < 3 { return "stable" }
        let formatted = String(format: "%.0f", abs(change))
        return change > 0 ? "up \(formatted)%" : "down \(formatted)%"
    }

    // MARK: - Smart Insights

    var smartInsights: [String] {
        var insights: [String] = []

        // Budget adherence
        let thisWeekTotal = weekEntries.reduce(0) { $0 + $1.lineTotal }
        let diff = weeklyBudgetGoal - thisWeekTotal
        if diff >= 0 {
            insights.append(String(format: "You're $%.2f under budget this week — great job staying on track!", diff))
        } else {
            insights.append(String(format: "You're $%.2f over budget this week. Consider skipping optional items.", abs(diff)))
        }

        // Top category shift
        if let topCat = categorySpendingBreakdown.first {
            insights.append(String(format: "%@ is your highest spending category at %@", topCat.category.displayName, topCat.2 > 0 ? "\(String(format: "%.0f", topCat.percentage))%" : "0%"))
        }

        // Shopping frequency
        let tripsCount = shoppingTrips.count
        if tripsCount > 0 {
            let cal = Calendar.current
            let oldestDate = shoppingTrips.last?.parsedDate ?? Date()
            let weeks = max(1, cal.dateComponents([.weekOfYear], from: oldestDate, to: Date()).weekOfYear ?? 1)
            let freq = Double(tripsCount) / Double(weeks)
            insights.append(String(format: "You shop %.1fx per week on average.", freq))
        }

        // Most frequent item alert
        if let topItem = mostFrequentItems.first, topItem.count >= 3 {
            insights.append("You frequently add \(topItem.itemName) (\(topItem.count) times) — consider buying in bulk.")
        }

        // Completion rate
        let allTrips = shoppingTrips
        if !allTrips.isEmpty {
            let avgCompletion = allTrips.reduce(0.0) { $0 + $1.completionRate } / Double(allTrips.count)
            insights.append(String(format: "You check off %.0f%% of items on average across all trips.", avgCompletion))
        }

        // Smart suggestion from frequent items
        let topSuggestions = mostFrequentItems.prefix(3).map { $0.itemName }
        if !topSuggestions.isEmpty {
            insights.append("Based on your history, you usually buy \(topSuggestions.joined(separator: ", ")) — add them?")
        }

        // Spending trend
        let trend = spendingTrendDirection
        if trend != "stable" {
            insights.append("Your spending is \(trend) compared to last week.")
        }

        return insights
    }

    // MARK: - Chart Data

    var weeklyChartData: [ChartDataPoint] {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return weeklySpendingData.map { ChartDataPoint(label: f.string(from: $0.date), value: $0.total) }
    }

    var monthlyChartData: [ChartDataPoint] {
        monthlySpendingData.map { ChartDataPoint(label: $0.weekLabel, value: $0.total) }
    }

    var categoryChartData: [ChartDataPoint] {
        categorySpendingBreakdown.map { ChartDataPoint(label: $0.category.displayName, value: $0.total) }
    }

    // MARK: - Analytics View Aliases

    var totalTrips: Int {
        shoppingTrips.count
    }

    var totalItemsBought: Int {
        entries.filter(\.isPurchased).count
    }

    var formattedTotalSpent: String {
        let total = entries.filter(\.isPurchased).reduce(0) { $0 + $1.lineTotal }
        return "$\(String(format: "%.2f", total))"
    }

    var formattedAverageBasket: String {
        let trips = shoppingTrips
        guard !trips.isEmpty else { return "$0.00" }
        let avg = trips.reduce(0) { $0 + $1.totalSpend } / Double(trips.count)
        return "$\(String(format: "%.2f", avg))"
    }

    var weeklySpendData: [ChartDataPoint] {
        monthlyChartData
    }

    var categorySpending: [GroceryCategorySpend] {
        categorySpendingBreakdown.map { item in
            GroceryCategorySpend(
                id: item.category.rawValue,
                category: item.category,
                total: item.total,
                percentage: item.percentage
            )
        }
    }

    var frequentItems: [GroceryFrequentItem] {
        mostFrequentItems.map { item in
            let category = entries.first { $0.itemName.lowercased().trimmingCharacters(in: .whitespaces) == item.itemName }?.category ?? .other
            return GroceryFrequentItem(
                id: item.itemName,
                itemName: item.itemName,
                count: item.count,
                lastCategory: category
            )
        }
    }

    var insights: [ModuleInsight] {
        moduleInsights
    }

    // MARK: - Module Insights

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        let thisWeekTotal = weekEntries.reduce(0) { $0 + $1.lineTotal }
        let diff = weeklyBudgetGoal - thisWeekTotal
        if diff >= 0 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Under Budget",
                message: String(format: "$%.2f remaining this week", diff)
            ))
        } else {
            result.append(ModuleInsight(
                type: .warning,
                title: "Over Budget",
                message: String(format: "$%.2f over weekly goal", abs(diff))
            ))
        }

        if budgetStreak >= 3 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(budgetStreak) Trip Streak",
                message: "You've stayed under budget for \(budgetStreak) consecutive trips!"
            ))
        }

        let trend = spendingTrendDirection
        if trend != "stable" {
            result.append(ModuleInsight(
                type: .trend,
                title: "Spending \(trend.hasPrefix("up") ? "Up" : "Down")",
                message: "Your spending is \(trend) vs last week"
            ))
        }

        if let topItem = mostFrequentItems.first, topItem.count >= 3 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Frequent Buy",
                message: "You add \(topItem.itemName) often — consider bulk purchasing"
            ))
        }

        if completionPercentage < 50 && !todayEntries.isEmpty {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Items Remaining",
                message: String(format: "%.0f%% of today's list still needs to be checked off", 100 - completionPercentage)
            ))
        }

        return result
    }
}