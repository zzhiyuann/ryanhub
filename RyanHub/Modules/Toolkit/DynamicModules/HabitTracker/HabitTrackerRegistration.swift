import SwiftUI

// MARK: - HabitTracker Registration

extension DynamicModuleRegistry {
    static func registerHabitTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "habitTracker",
            toolkitId: "habitTracker",
            displayName: "Habit Tracker",
            shortName: "Habits",
            subtitle: "Track daily habits with streaks",
            icon: "checkmark.seal.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(HabitTrackerView()) },
            dataProviderType: HabitTrackerDataProvider.self
        ))
    }
}
