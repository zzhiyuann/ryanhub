import SwiftUI

// MARK: - RecipeBook Registration

extension DynamicModuleRegistry {
    static func registerRecipeBook() {
        shared.register(DynamicModuleDescriptor(
            id: "recipeBook",
            toolkitId: "recipeBook",
            displayName: "Recipe Book",
            shortName: "Recipes",
            subtitle: "Save recipes with ingredients and prep time",
            icon: "fork.knife",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(RecipeBookView()) },
            dataProviderType: RecipeBookDataProvider.self
        ))
    }
}
