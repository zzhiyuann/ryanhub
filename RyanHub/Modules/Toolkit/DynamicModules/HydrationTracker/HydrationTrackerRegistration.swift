import SwiftUI

// MARK: - HydrationTracker Registration

extension DynamicModuleRegistry {
    static func registerHydrationTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "hydrationTracker",
            toolkitId: "hydrationTracker",
            displayName: "Hydration Tracker",
            shortName: "Hydration",
            subtitle: "Stay hydrated, stay healthy",
            icon: "drop.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(HydrationTrackerView()) },
            dataProviderType: HydrationTrackerDataProvider.self
        ))
    }
}
