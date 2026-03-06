import SwiftUI

struct RecipeBoxCookbookStatsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: RecipeBoxViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presented as sheet from nav bar button on collection view. Shows collection summary: total recipes, favorites count, total times cooked across all recipes in a horizontal stat card row. Most cooked top-3 recipes list with cook counts. Category breakdown as colored horizontal bars showing recipe count per MealCategory. Cuisine distribution as a simple ranked list. Average difficulty and average rating displays.")
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
