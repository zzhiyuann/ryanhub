import SwiftUI

struct PeopleNotesDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PeopleNotesViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Summary Card
                HubCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.todayEntries.count)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Text("Today's entries")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        Spacer()
                        Text("\(viewModel.entries.count) total")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }


                // Stats
                StatGrid {
                    StatCard(
                        title: "Today",
                        value: "\(viewModel.todayEntries.count)",
                        icon: "person.text.rectangle",
                        color: .hubPrimary
                    )
                    StatCard(
                        title: "Streak",
                        value: "\(viewModel.currentStreak)d",
                        icon: "flame.fill",
                        color: .hubAccentYellow
                    )
                    StatCard(
                        title: "Best",
                        value: "\(viewModel.longestStreak)d",
                        icon: "trophy.fill",
                        color: .hubAccentGreen
                    )
                    StatCard(
                        title: "Total",
                        value: "\(viewModel.entries.count)",
                        icon: "chart.bar.fill",
                        color: .hubPrimaryLight
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
