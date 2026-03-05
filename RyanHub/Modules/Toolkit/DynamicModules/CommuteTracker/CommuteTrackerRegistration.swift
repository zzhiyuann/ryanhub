import SwiftUI

// MARK: - CommuteTracker Registration

extension DynamicModuleRegistry {
    static func registerCommuteTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "commuteTracker",
            toolkitId: "commuteTracker",
            displayName: "Commute Tracker",
            shortName: "Commute",
            subtitle: "Track routes, time & commute patterns",
            icon: "car.circle.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(CommuteTrackerView()) },
            dataProviderType: CommuteTrackerDataProvider.self
        ))
    }
}
