import SwiftUI

// MARK: - PlantCareTracker Registration

extension DynamicModuleRegistry {
    static func registerPlantCareTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "plantCareTracker",
            toolkitId: "plantCareTracker",
            displayName: "Plant Care Tracker",
            shortName: "Plants",
            subtitle: "Keep your green friends thriving",
            icon: "leaf.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(PlantCareTrackerView()) },
            dataProviderType: PlantCareTrackerDataProvider.self
        ))
    }
}
