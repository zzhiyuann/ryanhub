import SwiftUI

// MARK: - CommuteLog Registration

extension DynamicModuleRegistry {
    static func registerCommuteLog() {
        shared.register(DynamicModuleDescriptor(
            id: "commuteLog",
            toolkitId: "commuteLog",
            displayName: "Commute Log",
            shortName: "Commute",
            subtitle: "Track daily commute time and route",
            icon: "car.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(CommuteLogView()) },
            dataProviderType: CommuteLogDataProvider.self
        ))
    }
}
