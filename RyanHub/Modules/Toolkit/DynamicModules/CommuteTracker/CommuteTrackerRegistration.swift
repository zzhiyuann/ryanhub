import SwiftUI

// MARK: - CommuteTracker Registration

extension DynamicModuleRegistry {
    static func registerCommuteTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "commuteTracker",
            toolkitId: "commuteTracker",
            displayName: "Commute Tracker",
            shortName: "Commute",
            subtitle: "Optimize your daily journey",
            icon: "car.front.waves.up",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(CommuteTrackerView()) },
            dataProviderType: CommuteTrackerDataProvider.self
        ))
    }
}
