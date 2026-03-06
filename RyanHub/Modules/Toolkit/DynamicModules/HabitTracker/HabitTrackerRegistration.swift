import SwiftUI

// MARK: - HabitTracker Registration

extension DynamicModuleRegistry {
    static func registerHabitTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "habitTracker",
            toolkitId: "habitTracker",
            displayName: "Habit Tracker",
            shortName: "Habits",
            subtitle: "Build streaks, build yourself",
            icon: "checkmark.circle.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(HabitTrackerView()) },
            dataProviderType: HabitTrackerDataProvider.self
        ))
    }
}
