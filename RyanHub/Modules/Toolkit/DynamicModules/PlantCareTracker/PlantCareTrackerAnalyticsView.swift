import SwiftUI

@MainActor
struct PlantCareTrackerAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PlantCareTrackerViewModel

    // MARK: - Computed Analytics

    private var entries: [PlantCareTrackerEntry] { viewModel.entries }

    private var totalCareEvents: Int { entries.count }

    private var uniquePlantCount: Int {
        Set(entries.map { $0.plantName }.filter { !$0.isEmpty }).count
    }

    private var wateringCount: Int {
        entries.filter { $0.careType == .water }.count
    }

    private var averageHealthScore: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.healthScore }) / Double(entries.count)
    }

    private var weeklyChartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return (0..<7).reversed().compactMap { daysAgo -> ChartDataPoint? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let count = entries.filter { calendar.isDate($0.parsedDate, inSameDayAs: date) }.count
            return ChartDataPoint(label: formatter.string(from: date), value: Double(count))
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var date = Date()
        while true {
            let hasCare = entries.contains { calendar.isDate($0.parsedDate, inSameDayAs: date) }
            if !hasCare { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    private var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Array(Set(entries.map { calendar.startOfDay(for: $0.parsedDate) })).sorted()
        guard !uniqueDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<uniqueDays.count {
            let diff = calendar.dateComponents([.day], from: uniqueDays[i - 1], to: uniqueDays[i]).day ?? 0
            if diff == 1 {
                current += 1
                if current > longest { longest = current }
            } else if diff > 1 {
                current = 1
            }
        }
        return longest
    }

    private var isCaredToday: Bool {
        entries.contains { Calendar.current.isDateInToday($0.parsedDate) }
    }

    private var careTypeBreakdown: [(CareType, Int)] {
        CareType.allCases.compactMap { type in
            let count = entries.filter { $0.careType == type }.count
            return count > 0 ? (type, count) : nil
        }.sorted { $0.1 > $1.1 }
    }

    private var topPlant: (name: String, count: Int)? {
        let grouped = Dictionary(grouping: entries.filter { !$0.plantName.isEmpty }, by: { $0.plantName })
        guard let top = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return (top.key, top.value.count)
    }

    private var heatmapData: [Date: Double] {
        let calendar = Calendar.current
        var data: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.parsedDate)
            data[day, default: 0] += 1
        }
        return data
    }

    private var generatedInsights: [ModuleInsight] {
        var insights: [ModuleInsight] = []

        if totalCareEvents == 0 {
            insights.append(ModuleInsight(
                type: .suggestion,
                title: "Start Your Garden Log",
                message: "Log your first plant care event to begin tracking health trends and care streaks."
            ))
            return insights
        }

        if averageHealthScore >= 4.0 {
            insights.append(ModuleInsight(
                type: .achievement,
                title: "Thriving Plants",
                message: "Your plants average a health score of \(String(format: "%.1f", averageHealthScore))/5 — outstanding care!"
            ))
        } else if averageHealthScore < 3.0 && totalCareEvents > 0 {
            insights.append(ModuleInsight(
                type: .warning,
                title: "Plants Need Attention",
                message: "Average health score is \(String(format: "%.1f", averageHealthScore))/5. Consider increasing care frequency."
            ))
        }

        if currentStreak >= 3 {
            insights.append(ModuleInsight(
                type: .trend,
                title: "Consistent Caregiver",
                message: "You've tended your plants \(currentStreak) days in a row. Your dedication shows!"
            ))
        }

        if let top = topPlant, uniquePlantCount > 1 {
            insights.append(ModuleInsight(
                type: .trend,
                title: "Favourite Plant",
                message: "\(top.name) is your most cared-for plant with \(top.count) logged events."
            ))
        }

        if uniquePlantCount >= 5 {
            insights.append(ModuleInsight(
                type: .achievement,
                title: "Plant Parent",
                message: "You're actively caring for \(uniquePlantCount) different plants — your green family is flourishing!"
            ))
        }

        if totalCareEvents > 0 {
            let waterPct = Int(Double(wateringCount) / Double(totalCareEvents) * 100)
            insights.append(ModuleInsight(
                type: .trend,
                title: "Watering Habits",
                message: "\(waterPct)% of your care events are waterings — the most vital task for plant health."
            ))
        }

        return insights
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Weekly care chart
                ModuleChartView(
                    title: "Care Events This Week",
                    subtitle: "\(totalCareEvents) total events logged",
                    dataPoints: weeklyChartData,
                    style: .bar,
                    color: Color.hubAccentGreen
                )

                // Streak
                HubCard {
                    StreakCounter(
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        unit: "days",
                        isActiveToday: isCaredToday
                    )
                }

                // Key stats
                StatGrid {
                    StatCard(
                        title: "Total Care Events",
                        value: "\(totalCareEvents)",
                        icon: "leaf.fill",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Plants Tracked",
                        value: "\(uniquePlantCount)",
                        icon: "tree.fill",
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Waterings",
                        value: "\(wateringCount)",
                        icon: "drop.fill",
                        color: .blue
                    )
                    StatCard(
                        title: "Avg Health",
                        value: totalCareEvents > 0 ? String(format: "%.1f", averageHealthScore) : "—",
                        icon: "heart.fill",
                        color: Color.hubAccentRed
                    )
                }

                // Care type breakdown
                if !careTypeBreakdown.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: "Care Type Breakdown")
                            ForEach(careTypeBreakdown, id: \.0.id) { type, count in
                                HStack(spacing: HubLayout.itemSpacing) {
                                    Image(systemName: type.icon)
                                        .foregroundStyle(Color.hubAccentGreen)
                                        .frame(width: 20)
                                    Text(type.displayName)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    Spacer()
                                    let pct = totalCareEvents > 0
                                        ? Int(Double(count) / Double(totalCareEvents) * 100)
                                        : 0
                                    Text("\(count) · \(pct)%")
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    CompactProgressRing(
                                        progress: totalCareEvents > 0 ? Double(count) / Double(totalCareEvents) : 0,
                                        color: Color.hubAccentGreen,
                                        size: 22
                                    )
                                }
                            }
                        }
                    }
                }

                // Activity heatmap
                CalendarHeatmap(
                    title: "Care Activity",
                    data: heatmapData,
                    color: Color.hubAccentGreen,
                    weeks: 12
                )

                // Insights
                InsightsList(insights: generatedInsights)
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}