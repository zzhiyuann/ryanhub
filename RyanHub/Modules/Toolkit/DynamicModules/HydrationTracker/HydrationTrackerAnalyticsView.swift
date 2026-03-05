import SwiftUI

struct HydrationTrackerAnalyticsView: View {
    let viewModel: HydrationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Analytics

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var todayEntries: [HydrationTrackerEntry] {
        viewModel.entries.filter { $0.dayKey == todayKey }
    }

    private var todayTotal: Double {
        todayEntries.reduce(0) { $0 + $1.effectiveOz }
    }

    private var todayProgress: Double {
        min(1.0, todayTotal / max(1, viewModel.dailyGoalOz))
    }

    private var totalOzAllTime: Double {
        viewModel.entries.reduce(0) { $0 + $1.effectiveOz }
    }

    private var allDayKeys: [String] {
        Array(Set(viewModel.entries.map { $0.dayKey })).sorted()
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()
        let goalOz = viewModel.dailyGoalOz

        let dayTotals: [String: Double] = viewModel.entries.reduce(into: [:]) { acc, e in
            acc[e.dayKey, default: 0] += e.effectiveOz
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        while true {
            let key = fmt.string(from: checkDate)
            if let total = dayTotals[key], total >= goalOz {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    private var longestStreak: Int {
        let goalOz = viewModel.dailyGoalOz
        let dayTotals: [String: Double] = viewModel.entries.reduce(into: [:]) { acc, e in
            acc[e.dayKey, default: 0] += e.effectiveOz
        }
        let sortedKeys = dayTotals.keys.sorted()
        guard !sortedKeys.isEmpty else { return 0 }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current

        var best = 0
        var current = 0
        var prevDate: Date? = nil

        for key in sortedKeys {
            guard let date = fmt.date(from: key) else { continue }
            let metGoal = (dayTotals[key] ?? 0) >= goalOz
            if metGoal {
                if let prev = prevDate, cal.dateComponents([.day], from: prev, to: date).day == 1 {
                    current += 1
                } else {
                    current = 1
                }
                best = max(best, current)
            } else {
                current = 0
            }
            prevDate = date
        }
        return best
    }

    private var isActiveToday: Bool {
        todayTotal >= viewModel.dailyGoalOz
    }

    private var daysWithGoalMet: Int {
        let goalOz = viewModel.dailyGoalOz
        let dayTotals: [String: Double] = viewModel.entries.reduce(into: [:]) { acc, e in
            acc[e.dayKey, default: 0] += e.effectiveOz
        }
        return dayTotals.values.filter { $0 >= goalOz }.count
    }

    private var avgDailyOz: Double {
        guard !allDayKeys.isEmpty else { return 0 }
        let dayTotals: [String: Double] = viewModel.entries.reduce(into: [:]) { acc, e in
            acc[e.dayKey, default: 0] += e.effectiveOz
        }
        let total = dayTotals.values.reduce(0, +)
        return total / Double(dayTotals.count)
    }

    private var weeklyChartData: [ChartDataPoint] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let labelFmt = DateFormatter()
        labelFmt.dateFormat = "EEE"

        let dayTotals: [String: Double] = viewModel.entries.reduce(into: [:]) { acc, e in
            acc[e.dayKey, default: 0] += e.effectiveOz
        }

        return (0..<7).reversed().compactMap { offset -> ChartDataPoint? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = fmt.string(from: date)
            let value = dayTotals[key] ?? 0
            return ChartDataPoint(label: labelFmt.string(from: date), value: value)
        }
    }

    private var heatmapData: [Date: Double] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let goalOz = viewModel.dailyGoalOz

        let dayTotals: [String: Double] = viewModel.entries.reduce(into: [:]) { acc, e in
            acc[e.dayKey, default: 0] += e.effectiveOz
        }

        return Dictionary(uniqueKeysWithValues: dayTotals.compactMap { key, total -> (Date, Double)? in
            guard let date = fmt.date(from: key) else { return nil }
            return (date, min(1.0, total / max(1, goalOz)))
        })
    }

    private var beverageBreakdown: [(BeverageType, Double)] {
        var totals: [BeverageType: Double] = [:]
        for entry in viewModel.entries {
            totals[entry.beverageType, default: 0] += entry.effectiveOz
        }
        return totals.sorted { $0.value > $1.value }
    }

    private var topContainer: ContainerType? {
        var counts: [ContainerType: Int] = [:]
        for entry in viewModel.entries {
            counts[entry.containerType, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Today Progress Ring
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Today's Hydration")
                        ProgressRingView(
                            progress: todayProgress,
                            current: String(format: "%.0f", todayTotal),
                            unit: "oz",
                            goal: String(format: "of %.0f oz goal", viewModel.dailyGoalOz),
                            color: .hubPrimary,
                            size: 140,
                            lineWidth: 12
                        )
                        HStack {
                            Text("\(todayEntries.count) drink\(todayEntries.count == 1 ? "" : "s") logged today")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }

                // Stats Grid
                StatGrid {
                    StatCard(
                        title: "Avg Daily",
                        value: String(format: "%.0f oz", avgDailyOz),
                        icon: "drop.fill",
                        color: .hubPrimary
                    )
                    StatCard(
                        title: "Goal Met",
                        value: "\(daysWithGoalMet)d",
                        icon: "checkmark.seal.fill",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Current Streak",
                        value: "\(currentStreak)d",
                        icon: "flame.fill",
                        color: Color.hubAccentYellow
                    )
                    StatCard(
                        title: "Best Streak",
                        value: "\(longestStreak)d",
                        icon: "trophy.fill",
                        color: Color.hubAccentGreen
                    )
                }

                // Weekly Bar Chart
                ModuleChartView(
                    title: "Last 7 Days",
                    subtitle: "Effective oz per day",
                    dataPoints: weeklyChartData,
                    style: .bar,
                    color: .hubPrimary,
                    showArea: false
                )

                // Streak Counter
                HubCard {
                    StreakCounter(
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        unit: "days",
                        isActiveToday: isActiveToday
                    )
                }

                // Calendar Heatmap
                CalendarHeatmap(
                    title: "Hydration History",
                    data: heatmapData,
                    color: .hubPrimary,
                    weeks: 12
                )

                // Beverage Breakdown
                if !beverageBreakdown.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: "Beverage Breakdown")
                            let grandTotal = beverageBreakdown.reduce(0) { $0 + $1.1 }
                            ForEach(beverageBreakdown.prefix(5), id: \.0.id) { type, oz in
                                HStack(spacing: HubLayout.itemSpacing) {
                                    Image(systemName: type.icon)
                                        .foregroundStyle(Color.hubPrimary)
                                        .frame(width: 20)
                                    Text(type.displayName)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(String(format: "%.0f oz", oz))
                                            .font(.hubCaption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        if grandTotal > 0 {
                                            Text(String(format: "%.0f%%", oz / grandTotal * 100))
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                // Hydration Summary Card
                HubCard {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "All-Time Summary")
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: "%.0f oz", totalOzAllTime))
                                    .font(.hubTitle)
                                    .foregroundStyle(Color.hubPrimary)
                                Text("Total intake tracked")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(viewModel.entries.count)")
                                    .font(.hubTitle)
                                    .foregroundStyle(Color.hubAccentGreen)
                                Text("Drinks logged")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                        if let container = topContainer {
                            Divider()
                            HStack(spacing: 8) {
                                Image(systemName: container.icon)
                                    .foregroundStyle(Color.hubAccentYellow)
                                Text("Favourite container: \(container.displayName)")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }
                }

                // Insights
                if !viewModel.insights.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: "Insights")
                            ForEach(viewModel.insights) { insight in
                                HydrationInsightRow(insight: insight, colorScheme: colorScheme)
                                if insight.id != viewModel.insights.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}

// MARK: - Insight Row

private struct HydrationInsightRow: View {
    let insight: HydrationInsight
    let colorScheme: ColorScheme

    private var accentColor: Color {
        switch insight.accentColor {
        case "green":  return .hubAccentGreen
        case "red":    return .hubAccentRed
        case "yellow": return .hubAccentYellow
        default:       return .hubPrimary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
            Image(systemName: insight.icon)
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text(insight.message)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}