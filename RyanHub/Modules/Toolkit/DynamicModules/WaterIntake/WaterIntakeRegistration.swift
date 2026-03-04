import SwiftUI

// MARK: - WaterIntake Registration

extension DynamicModuleRegistry {
    static func registerWaterIntake() {
        shared.register(DynamicModuleDescriptor(
            id: "waterIntake",
            toolkitId: "waterIntake",
            displayName: "Water Intake",
            shortName: "Water",
            subtitle: "Track daily hydration",
            icon: "drop.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(WaterIntakeView()) },
            dataProviderType: WaterIntakeDataProvider.self
        ))
    }
}
