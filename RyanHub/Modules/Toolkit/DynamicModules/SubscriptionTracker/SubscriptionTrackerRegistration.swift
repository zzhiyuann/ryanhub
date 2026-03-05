import SwiftUI

// MARK: - SubscriptionTracker Registration

extension DynamicModuleRegistry {
    static func registerSubscriptionTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "subscriptionTracker",
            toolkitId: "subscriptionTracker",
            displayName: "Subscription Tracker",
            shortName: "Subscriptions",
            subtitle: "Know where every dollar goes, every month",
            icon: "creditcard.and.123",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(SubscriptionTrackerView()) },
            dataProviderType: SubscriptionTrackerDataProvider.self
        ))
    }
}
