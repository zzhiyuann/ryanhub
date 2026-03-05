import SwiftUI

// MARK: - SubscriptionTracker Registration

extension DynamicModuleRegistry {
    static func registerSubscriptionTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "subscriptionTracker",
            toolkitId: "subscriptionTracker",
            displayName: "Subscription Tracker",
            shortName: "Subscriptions",
            subtitle: "Track recurring costs & save money",
            icon: "creditcard.and.123",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(SubscriptionTrackerView()) },
            dataProviderType: SubscriptionTrackerDataProvider.self
        ))
    }
}
