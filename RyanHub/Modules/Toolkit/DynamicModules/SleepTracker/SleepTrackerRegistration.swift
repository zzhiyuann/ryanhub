import SwiftUI

// MARK: - SleepTracker Registration

extension DynamicModuleRegistry {
    static func registerSleepTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "sleepTracker",
            toolkitId: "sleepTracker",
            displayName: "Sleep Tracker",
            shortName: "Sleep",
            subtitle: "Track sleep quality and patterns",
            icon: "moon.stars.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(SleepTrackerView()) },
            dataProviderType: SleepTrackerDataProvider.self
        ))
    }
}
