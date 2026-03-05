import SwiftUI

// MARK: - ScreenTimeTracker Registration

extension DynamicModuleRegistry {
    static func registerScreenTimeTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "screenTimeTracker",
            toolkitId: "screenTimeTracker",
            displayName: "Screen Time Tracker",
            shortName: "Screen Time",
            subtitle: "Set goals and reclaim your hours",
            icon: "hourglass",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(ScreenTimeTrackerView()) },
            dataProviderType: ScreenTimeTrackerDataProvider.self
        ))
    }
}
