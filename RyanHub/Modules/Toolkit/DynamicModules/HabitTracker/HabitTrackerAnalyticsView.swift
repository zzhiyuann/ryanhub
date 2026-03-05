import SwiftUI

struct HabitTrackerAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HabitTrackerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing) {
                summaryStatsSection
                streakSection
                chartSection
                heatmapSection
                categorySection
                dayOfWeekSection
                insightsSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Summary Stats

    private var summaryStatsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Overview")
            StatGrid {
                StatCard(
                    title: "Total Completions",
                    value: "\(viewModel.totalCompletions)",
                    icon: "checkmark.seal.fill",
                    color: Color.hubPrimary
                )
                StatCard(
                    title: "Completion Rate",
                    value: String(format: "%.0f%%", viewModel.overallCompletionRate * 100),
                    icon: "percent",
                    color: Color.hubAccentGreen
                )
                StatCard(
                    title: "Total Entries",
                    value: "\(viewModel.entries.count)",
                    icon: "list.bullet.clipboard.fill",
                    color: Color.hubAccentYellow
                )
                StatCard(
                    title: "Active Habits",
                    value: "\(activeHabitCount)",
                    icon: "flame.fill",
                    color: Color.hubAccentRed
                )
            }
        }
    }

    private var activeHabitCount: Int {
        Set(viewModel.entries.map { $0.habitName }).count
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Streaks")
            HubCard {
                StreakCounter(
                    currentStreak: viewModel.currentStreak,
                    longestStreak: viewModel.longestStreak,
                    unit: "days",
                    isActiveToday: viewModel.isActiveToday
                )
            }
            if !viewModel.streakSummaries.isEmpty {
                HubCard {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        Text("Per-Habit Streaks")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        ForEach(viewModel.streakSummaries.prefix(5)) { summary in
                            HabitStreakRow(summary: summary, colorScheme: colorScheme)
                            if summary.id != viewModel.streakSummaries.prefix(5).last?.id {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Completion Trend")
            ModuleChartView(
                title: "Daily Completions",
                subtitle: "Last 30 days",
                dataPoints: viewModel.chartData,
                style: .bar,
                color: Color.hubPrimary,
                showArea: true
            )
        }
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Activity Heatmap")
            HubCard {
                CalendarHeatmap(
                    title: "Habit Activity",
                    data: viewModel.heatmapDataDictionary,
                    color: Color.hubPrimary,
                    weeks: 12
                )
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        Group {
            if !viewModel.categoryBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "By Category")
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            ForEach(viewModel.categoryBreakdowns) { breakdown in
                                HabitCategoryRow(breakdown: breakdown, colorScheme: colorScheme)
                                if breakdown.id != viewModel.categoryBreakdowns.last?.id {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Day of Week Section

    private var dayOfWeekSection: some View {
        Group {
            if !viewModel.dayOfWeekStats.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Best Days")
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            Text("Completion Rate by Day")
                                .font(.hubHeading)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(viewModel.dayOfWeekStats) { stat in
                                    DayBarView(stat: stat, colorScheme: colorScheme)
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        Group {
            if !viewModel.moduleInsights.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Insights")
                    InsightsList(insights: viewModel.moduleInsights)
                }
            }
        }
    }
}

// MARK: - Subviews

private struct HabitStreakRow: View {
    let summary: HabitStreakSummary
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "flame.fill")
                .foregroundStyle(summary.isPersonalBest ? Color.hubAccentRed : Color.hubAccentYellow)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.habitName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                if summary.isPersonalBest {
                    Text("Personal best!")
                        .font(.hubCaption)
                        .foregroundStyle(Color.hubAccentGreen)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.streakLabel)
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.hubPrimary)
                Text("best: \(summary.bestStreak)d")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct HabitCategoryRow: View {
    let breakdown: HabitCategoryBreakdown
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: breakdown.category.icon)
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 20)

                Text(breakdown.category.displayName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Text("\(breakdown.count) entries")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Text(breakdown.completionPercent)
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.hubAccentGreen)
                    .frame(width: 44, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.hubPrimary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.hubPrimary)
                        .frame(width: geo.size.width * breakdown.completionRate, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
    }
}

private struct DayBarView: View {
    let stat: DayOfWeekStat
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.hubPrimary.opacity(0.2 + 0.8 * stat.rate))
                .frame(height: max(4, 64 * stat.rate))
            Text(stat.day)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Text(stat.displayRate)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}