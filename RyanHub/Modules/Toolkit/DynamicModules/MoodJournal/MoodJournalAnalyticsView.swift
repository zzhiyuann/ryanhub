import SwiftUI

struct MoodJournalAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // MARK: - Overview Stats
                SectionHeader(title: "Overview")
                StatGrid {
                    StatCard(
                        title: "Total Entries",
                        value: "\(viewModel.totalEntries)",
                        icon: "face.smiling.fill",
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Avg Mood",
                        value: String(format: "%.1f / 10", viewModel.averageMood),
                        icon: "heart.fill",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Avg Energy",
                        value: String(format: "%.1f / 10", viewModel.averageEnergy),
                        icon: "bolt.fill",
                        color: Color.hubAccentYellow
                    )
                    StatCard(
                        title: "Avg Anxiety",
                        value: String(format: "%.1f / 10", viewModel.averageAnxiety),
                        icon: "waveform.path.ecg",
                        color: Color.hubAccentRed
                    )
                }

                // MARK: - Streak
                SectionHeader(title: "Consistency")
                StreakCounter(
                    currentStreak: viewModel.currentStreak,
                    longestStreak: viewModel.longestStreak,
                    unit: "days",
                    isActiveToday: viewModel.isActiveToday
                )

                // MARK: - Mood Trend Chart
                SectionHeader(title: "Mood Trend")
                ModuleChartView(
                    title: "7-Day Mood",
                    subtitle: "Daily average mood rating (1–10)",
                    dataPoints: viewModel.weeklyChartData,
                    style: .line,
                    color: Color.hubPrimary,
                    showArea: true
                )

                // MARK: - Mood Profile
                SectionHeader(title: "Mood Profile")
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        MoodProfileRow(
                            label: "Overall Trend",
                            value: viewModel.trendDirection.label,
                            icon: viewModel.trendDirection.icon,
                            color: trendColor(for: viewModel.trendDirection),
                            colorScheme: colorScheme
                        )
                        Divider()
                        if let activity = viewModel.mostFrequentActivity {
                            MoodProfileRow(
                                label: "Top Activity",
                                value: activity.displayName,
                                icon: activity.icon,
                                color: Color.hubPrimary,
                                colorScheme: colorScheme
                            )
                            Divider()
                        }
                        if let context = viewModel.mostFrequentContext {
                            MoodProfileRow(
                                label: "Common Setting",
                                value: context.displayName,
                                icon: context.icon,
                                color: Color.hubAccentGreen,
                                colorScheme: colorScheme
                            )
                        }
                    }
                }

                // MARK: - Activity Heatmap
                SectionHeader(title: "Activity")
                CalendarHeatmap(
                    title: "Journal Activity",
                    data: viewModel.heatmapData,
                    color: Color.hubPrimary,
                    weeks: 12
                )

                // MARK: - Insights
                if !viewModel.insights.isEmpty {
                    SectionHeader(title: "Insights")
                    HubCard {
                        VStack(spacing: HubLayout.itemSpacing) {
                            ForEach(viewModel.insights) { insight in
                                MoodInsightRow(insight: insight, colorScheme: colorScheme)
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

    private func trendColor(for direction: TrendDirection) -> Color {
        switch direction {
        case .up:     return Color.hubAccentGreen
        case .down:   return Color.hubAccentRed
        case .stable: return Color.hubAccentYellow
        }
    }
}

// MARK: - MoodProfileRow

private struct MoodProfileRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24)

            Text(label)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            Text(value)
                .font(.hubBody)
                .fontWeight(.semibold)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }
}

// MARK: - MoodInsightRow

private struct MoodInsightRow: View {
    let insight: MoodInsight
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
            Image(systemName: insight.icon)
                .foregroundStyle(insight.isAlert ? Color.hubAccentRed : Color.hubPrimary)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(insight.body)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}