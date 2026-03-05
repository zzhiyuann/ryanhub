import SwiftUI

struct FocusSessionAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FocusSessionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Weekly Chart
                ModuleChartView(
                    title: "This Week",
                    subtitle: "Daily entries",
                    dataPoints: viewModel.weeklyChartData,
                    style: .bar,
                    color: .hubPrimary
                )

                // Insights
                if !viewModel.insights.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Insights")
                        InsightsList(insights: viewModel.insights)
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
                                Text("\(viewModel.longestStreak) days")
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
