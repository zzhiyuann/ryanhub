import SwiftUI

// MARK: - SubscriptionTracker Registration

extension DynamicModuleRegistry {
    static func registerSubscriptionTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "subscriptionTracker",
            toolkitId: "subscriptionTracker",
            displayName: "Subscription Tracker",
            shortName: "Subs",
            subtitle: "Track recurring subscriptions",
            icon: "creditcard.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(SubscriptionTrackerView()) },
            dataProviderType: SubscriptionTrackerDataProvider.self
        ))
    }
}
