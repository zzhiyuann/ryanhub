import SwiftUI

struct HydrationTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HydrationTrackerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Progress Ring
                HubCard {
                    HStack(spacing: 20) {
                        ProgressRingView(
                            progress: viewModel.todayProgress,
                            current: "\(viewModel.todayTotalMl)",
                            unit: "ml",
                            goal: "of \(viewModel.dailyGoalMl)ml",
                            color: .hubPrimary,
                            size: 100
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily Goal")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("\(viewModel.todayGlassCount) glasses today")
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
                        value: "\(viewModel.todayTotalMl) ml",
                        icon: "drop.fill",
                        color: .hubPrimary
                    )
                    StatCard(
                        title: "Weekly Avg",
                        value: "\(viewModel.weeklyAverageMl) ml",
                        icon: "calendar",
                        color: .hubPrimaryLight
                    )
                    StatCard(
                        title: "Streak",
                        value: "\(viewModel.currentStreak)d",
                        icon: "flame.fill",
                        color: .hubAccentYellow
                    )
                    StatCard(
                        title: "Total",
                        value: "\(viewModel.entries.count)",
                        icon: "chart.bar.fill",
                        color: .hubAccentGreen
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
