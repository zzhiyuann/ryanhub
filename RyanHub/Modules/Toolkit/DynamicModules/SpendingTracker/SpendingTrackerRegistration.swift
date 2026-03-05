import SwiftUI

// MARK: - SpendingTracker Registration

extension DynamicModuleRegistry {
    static func registerSpendingTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "spendingTracker",
            toolkitId: "spendingTracker",
            displayName: "Spending Tracker",
            shortName: "Spending",
            subtitle: "Track daily expenses & stay on budget",
            icon: "creditcard.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(SpendingTrackerView()) },
            dataProviderType: SpendingTrackerDataProvider.self
        ))
    }
}
