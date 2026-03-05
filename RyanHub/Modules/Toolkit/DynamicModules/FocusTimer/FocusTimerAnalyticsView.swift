import SwiftUI

struct FocusTimerAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FocusTimerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Weekly Chart
                ModuleChartView(
                    title: "This Week",
                    subtitle: "Daily entries",
                    dataPoints: viewModel.chartData.suffix(7).map { ChartDataPoint(label: $0.date.formatted(.dateTime.weekday(.abbreviated)), value: Double($0.totalMinutes)) },
                    style: .bar,
                    color: .hubPrimary
                )

                // Insights
                if !viewModel.insights.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Insights")
                        ForEach(viewModel.insights, id: \.self) { insight in
                            HubCard {
                                Text(insight)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                        }
                    }
                }

                // Stats summary
                HubCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Entries")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("\(viewModel.entries.count)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Streak")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("\(viewModel.currentStreak) days")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.hubAccentYellow)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Best Streak")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("\(viewModel.currentStreak) days")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.hubAccentGreen)
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
