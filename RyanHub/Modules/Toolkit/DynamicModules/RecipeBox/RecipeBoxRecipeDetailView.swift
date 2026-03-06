import SwiftUI

struct RecipeBoxRecipeDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: RecipeBoxViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pushed from collection. Hero header with title, category/cuisine badges, difficulty, and time pills (prep|cook|total). Heart toggle and edit button in nav bar. Three sections: (1) Ingredients with servings adjuster stepper that scales quantities, each ingredient is a tappable checkbox row with strikethrough when checked for cooking mode. (2) Numbered instruction step cards with large readable text. (3) Notes section. Sticky bottom bar with 'I Made This!' button that increments cookCount with a brief celebration animation and shows total cook count.")
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
