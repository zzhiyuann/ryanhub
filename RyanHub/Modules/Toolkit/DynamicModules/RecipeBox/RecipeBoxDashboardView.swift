import SwiftUI

struct RecipeBoxDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: RecipeBoxViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Summary Card
                HubCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.entries.count)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Text("Total recipes")
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
                        title: "Favorites",
                        value: "\(viewModel.favoriteRecipes.count)",
                        icon: "heart.fill",
                        color: .hubAccentRed
                    )
                    StatCard(
                        title: "Streak",
                        value: "\(viewModel.cookingStreak)d",
                        icon: "flame.fill",
                        color: .hubAccentYellow
                    )
                    StatCard(
                        title: "Cooked",
                        value: "\(viewModel.totalTimesCooked)",
                        icon: "frying.pan.fill",
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
                    currentStreak: viewModel.cookingStreak,
                    longestStreak: viewModel.cookingStreak,
                    isActiveToday: viewModel.recipesAddedThisWeek > 0
                )

                // Recent Entries
                if !viewModel.entries.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Recent Recipes")
                        ForEach(viewModel.entries.prefix(5)) { entry in
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
