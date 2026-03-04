import SwiftUI

// MARK: - GroceryList Registration

extension DynamicModuleRegistry {
    static func registerGroceryList() {
        shared.register(DynamicModuleDescriptor(
            id: "groceryList",
            toolkitId: "groceryList",
            displayName: "Grocery List",
            shortName: "Grocery",
            subtitle: "Shopping list with checkoffs",
            icon: "cart.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(GroceryListView()) },
            dataProviderType: GroceryListDataProvider.self
        ))
    }
}
