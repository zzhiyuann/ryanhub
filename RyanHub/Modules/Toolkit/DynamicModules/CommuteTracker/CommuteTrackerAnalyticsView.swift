import SwiftUI

struct CommuteTrackerAnalyticsView: View {
    let viewModel: CommuteTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // MARK: Weekly Duration Chart
                ModuleChartView(
                    title: "Weekly Commute Duration",
                    subtitle: "Minutes per day",
                    dataPoints: viewModel.weeklyChartData,
                    style: .bar,
                    color: Color.hubPrimary,
                    showArea: false
                )

                // MARK: Core Stats
                StatGrid {
                    StatCard(
                        title: "Total Commutes",
                        value: "\(viewModel.totalCommutes)",
                        icon: "car.fill",
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Avg Duration",
                        value: "\(Int(viewModel.averageDurationMinutes)) min",
                        icon: "clock.fill",
                        color: Color.hubAccentYellow
                    )
                    StatCard(
                        title: "Total Spent",
                        value: String(format: "$%.0f", viewModel.totalCostDollars),
                        icon: "dollarsign.circle.fill",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Avg Delay",
                        value: "\(Int(viewModel.averageDelayMinutes)) min",
                        icon: "exclamationmark.triangle.fill",
                        color: Color.hubAccentRed
                    )
                }

                // MARK: Streak
                HubCard {
                    StreakCounter(
                        currentStreak: viewModel.currentStreak,
                        longestStreak: viewModel.longestStreak,
                        unit: "days",
                        isActiveToday: viewModel.isActiveToday
                    )
                }

                // MARK: Commute Details
                HubCard {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Commute Breakdown")

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Most Used Mode")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.mostUsedTransportMode?.icon ?? "car.fill")
                                        .foregroundStyle(Color.hubPrimary)
                                    Text(viewModel.mostUsedTransportMode?.displayName ?? "—")
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Avg Experience")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.hubAccentYellow)
                                    Text(String(format: "%.1f / 5", viewModel.averageExperienceRating))
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                }
                            }
                        }

                        Divider()

                        HStack {
                            commuteSplitStat(
                                label: "To Work",
                                value: "\(viewModel.toWorkCount)",
                                icon: "building.2",
                                color: Color.hubPrimary
                            )
                            Spacer()
                            commuteSplitStat(
                                label: "From Work",
                                value: "\(viewModel.fromWorkCount)",
                                icon: "house.fill",
                                color: Color.hubAccentGreen
                            )
                            Spacer()
                            commuteSplitStat(
                                label: "With Delays",
                                value: "\(viewModel.delayedCommuteCount)",
                                icon: "exclamationmark.circle",
                                color: Color.hubAccentRed
                            )
                        }
                    }
                }

                // MARK: Activity Heatmap
                HubCard {
                    CalendarHeatmap(
                        title: "Commute Activity",
                        data: viewModel.heatmapData,
                        color: Color.hubPrimary,
                        weeks: 12
                    )
                }

                // MARK: Top Routes
                if !viewModel.routeRankings.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Top Routes")
                        HubCard {
                            VStack(spacing: HubLayout.itemSpacing) {
                                ForEach(Array(viewModel.routeRankings.prefix(5).enumerated()), id: \.element.id) { index, route in
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                            .frame(width: 18)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(route.routeName.isEmpty ? "Unnamed Route" : route.routeName)
                                                .font(.hubBody)
                                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                                .lineLimit(1)
                                            Text("\(route.tripCount) trips")
                                                .font(.hubCaption)
                                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                        }

                                        Spacer()

                                        Text(route.formattedAvg)
                                            .font(.hubBody)
                                            .foregroundStyle(Color.hubPrimary)
                                    }

                                    if index < min(viewModel.routeRankings.count, 5) - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: Insights
                if !viewModel.insights.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Insights")
                        InsightsList(insights: viewModel.insights)
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func commuteSplitStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            Text(label)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}