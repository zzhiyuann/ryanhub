import SwiftUI

// MARK: - DailyAffirmations Registration

extension DynamicModuleRegistry {
    static func registerDailyAffirmations() {
        shared.register(DynamicModuleDescriptor(
            id: "dailyAffirmations",
            toolkitId: "dailyAffirmations",
            displayName: "Daily Affirmations",
            shortName: "Affirmations",
            subtitle: "Store and display daily affirmations",
            icon: "quote.bubble.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(DailyAffirmationsView()) },
            dataProviderType: DailyAffirmationsDataProvider.self
        ))
    }
}
