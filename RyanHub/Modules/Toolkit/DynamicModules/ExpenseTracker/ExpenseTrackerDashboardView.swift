import SwiftUI

struct ExpenseTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ExpenseTrackerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Today's spending summary
                HubCard {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Spending")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Text(String(format: "$%.2f", viewModel.todayTotal))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Text("\(viewModel.todayEntries.count) transactions")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        Spacer()
                    }
                }

                // Stats
                StatGrid {
                    StatCard(
                        title: "Today",
                        value: String(format: "$%.0f", viewModel.todayTotal),
                        icon: "creditcard.and.123",
                        color: .hubPrimary
                    )
                    StatCard(
                        title: "This Week",
                        value: String(format: "$%.0f", viewModel.weeklyTotal),
                        icon: "calendar",
                        color: .hubPrimaryLight
                    )
                    StatCard(
                        title: "This Month",
                        value: String(format: "$%.0f", viewModel.monthlyTotal),
                        icon: "chart.bar.fill",
                        color: .hubAccentGreen
                    )
                    StatCard(
                        title: "Streak",
                        value: "\(viewModel.currentStreak)d",
                        icon: "flame.fill",
                        color: .hubAccentYellow
                    )
                }


                // Streak
                StreakCounter(
                    currentStreak: viewModel.currentStreak,
                    longestStreak: viewModel.longestStreak,
                    isActiveToday: !viewModel.todayEntries.isEmpty
                )

                // Recent Entries
                if !viewModel.todayEntries.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Today")
                        ForEach(viewModel.todayEntries.reversed()) { entry in
                            HubCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.summaryLine).font(.hubBody).foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Text(entry.date)
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }
                                    Spacer()
                                    Button {
                                        Task { await viewModel.deleteEntry(entry) }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.hubAccentRed)
                                    }
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
