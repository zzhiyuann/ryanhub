import SwiftUI

struct MoodJournalDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Progress Ring
                HubCard {
                    HStack(spacing: 20) {
                        ProgressRingView(
                            progress: Double(viewModel.todayEntries.count) / Double(2),
                            current: "\(viewModel.todayEntries.count)",
                            unit: "today",
                            goal: "of 2",
                            color: .hubPrimary,
                            size: 100
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of mood check-ins per day")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("\(viewModel.entries.count) total entries")
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
                        value: "\(viewModel.todayEntries.count)",
                        icon: "brain.head.profile",
                        color: .hubPrimary
                    )
                    StatCard(
                        title: "This Week",
                        value: "\(viewModel.weeklyChartData.reduce(0) { $0 + Int($1.value) })",
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
