import SwiftUI

// MARK: - PlantWatering Registration

extension DynamicModuleRegistry {
    static func registerPlantWatering() {
        shared.register(DynamicModuleDescriptor(
            id: "plantWatering",
            toolkitId: "plantWatering",
            displayName: "Plant Watering",
            shortName: "Plants",
            subtitle: "Track watering schedule for houseplants",
            icon: "leaf.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(PlantWateringView()) },
            dataProviderType: PlantWateringDataProvider.self
        ))
    }
}
