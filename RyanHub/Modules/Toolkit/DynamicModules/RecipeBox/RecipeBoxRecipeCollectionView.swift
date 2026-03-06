import SwiftUI

struct RecipeBoxRecipeCollectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: RecipeBoxViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Root NavigationStack view. 2-column LazyVGrid of recipe cards showing title, MealCategory badge, total time (prep+cook), difficulty dots, and star rating. Search bar at top filters by title and ingredients. Horizontal scrolling MealCategory filter chips below search. Long-press for quick actions (favorite, delete). Empty state with cookbook illustration and add prompt. Nav bar trailing button opens CookbookStatsView as sheet.")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
                ForEach(viewModel.entries) { entry in
                    HubCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.summaryLine)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text(entry.date)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}
