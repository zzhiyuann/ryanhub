import SwiftUI

struct SpendingTrackerTrendsView: View {
    let viewModel: SpendingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                weeklyBarChartSection
                weekOverWeekSection
                streakSection
                insightsSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Weekly Bar Chart

    private var weeklyBarChartSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "This Week")

            HubCard {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    Text("Daily Spending")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("vs $\(String(format: "%.0f", viewModel.dailyBudget)) daily budget")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    weeklyBarChart
                        .frame(height: 180)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var weeklyBarChart: some View {
        let data = viewModel.weeklyChartData
        let maxValue = max(data.map(\.value).max() ?? 0, viewModel.dailyBudget) * 1.15

        return GeometryReader { geo in
            let barWidth = (geo.size.width - CGFloat(data.count - 1) * 4) / CGFloat(data.count)
            let chartHeight = geo.size.height - 24

            ZStack(alignment: .bottom) {
                // Budget reference line
                if maxValue > 0 {
                    let budgetY = chartHeight * (1 - viewModel.dailyBudget / maxValue)
                    HStack(spacing: 0) {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: budgetY))
                            path.addLine(to: CGPoint(x: geo.size.width, y: budgetY))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.hubAccentYellow.opacity(0.7))
                    }
                    .frame(height: chartHeight)

                    // Budget label
                    Text("$\(String(format: "%.0f", viewModel.dailyBudget))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.hubAccentYellow)
                        .position(x: geo.size.width - 18, y: budgetY - 10)
                }

                // Bars + labels
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        VStack(spacing: 4) {
                            if maxValue > 0 && point.value > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(point.value > viewModel.dailyBudget ? Color.hubAccentRed : Color.hubPrimary)
                                    .frame(
                                        width: barWidth,
                                        height: max(4, chartHeight * point.value / maxValue)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.hubPrimary.opacity(0.15))
                                    .frame(width: barWidth, height: 4)
                            }

                            Text(point.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .frame(height: 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Week-over-Week Comparison

    private var weekOverWeekSection: some View {
        let change = viewModel.weekOverWeekChange
        let isDown = change < 0
        let changeText = String(format: "%.0f%%", abs(change))

        return HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: isDown ? "arrow.down.right" : "arrow.up.right")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isDown ? Color.hubAccentGreen : Color.hubAccentRed)
                    .frame(width: 40, height: 40)
                    .background(
                        (isDown ? Color.hubAccentGreen : Color.hubAccentRed).opacity(0.12)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.lastWeekTotal > 0 {
                        Text("\(changeText) \(isDown ? "less" : "more") than last week")
                            .font(.hubBody)
                            .fontWeight(.medium)
                            .foregroundStyle(isDown ? Color.hubAccentGreen : Color.hubAccentRed)
                    } else {
                        Text("No data from last week")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text("This week: $\(String(format: "%.2f", viewModel.thisWeekTotal))")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Budget Streak")

            StreakCounter(
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak,
                unit: "days",
                isActiveToday: !viewModel.isOverBudget
            )
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        let trendsInsights = Array(viewModel.insights.prefix(3))

        return Group {
            if !trendsInsights.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Insights")

                    ForEach(Array(trendsInsights.enumerated()), id: \.offset) { _, insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
    }
}