import SwiftUI

// MARK: - ScreenTimeGoal Registration

extension DynamicModuleRegistry {
    static func registerScreenTimeGoal() {
        shared.register(DynamicModuleDescriptor(
            id: "screenTimeGoal",
            toolkitId: "screenTimeGoal",
            displayName: "Screen Time Goal",
            shortName: "Screen Time",
            subtitle: "Set and track daily screen time limits",
            icon: "hourglass.circle.fill",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(ScreenTimeGoalView()) },
            dataProviderType: ScreenTimeGoalDataProvider.self
        ))
    }
}
