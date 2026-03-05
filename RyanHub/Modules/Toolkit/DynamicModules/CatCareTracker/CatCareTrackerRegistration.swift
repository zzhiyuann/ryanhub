import SwiftUI

// MARK: - CatCareTracker Registration

extension DynamicModuleRegistry {
    static func registerCatCareTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "catCareTracker",
            toolkitId: "catCareTracker",
            displayName: "Cat Care Tracker",
            shortName: "Cat Care",
            subtitle: "Feeding, vet visits & wellness for your cat",
            icon: "cat.fill",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(CatCareTrackerView()) },
            dataProviderType: CatCareTrackerDataProvider.self
        ))
    }
}
