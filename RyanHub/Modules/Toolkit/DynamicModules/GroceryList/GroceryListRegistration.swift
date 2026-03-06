import SwiftUI

// MARK: - GroceryList Registration

extension DynamicModuleRegistry {
    static func registerGroceryList() {
        shared.register(DynamicModuleDescriptor(
            id: "groceryList",
            toolkitId: "groceryList",
            displayName: "Grocery List",
            shortName: "Grocery",
            subtitle: "Smart shopping checklist",
            icon: "cart.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(GroceryListView()) },
            dataProviderType: GroceryListDataProvider.self
        ))
    }
}
