import SwiftUI

// MARK: - RecipeBox Registration

extension DynamicModuleRegistry {
    static func registerRecipeBox() {
        shared.register(DynamicModuleDescriptor(
            id: "recipeBox",
            toolkitId: "recipeBox",
            displayName: "Recipe Box",
            shortName: "Recipes",
            subtitle: "Your personal digital cookbook",
            icon: "book.closed.fill",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(RecipeBoxView()) },
            dataProviderType: RecipeBoxDataProvider.self
        ))
    }
}
