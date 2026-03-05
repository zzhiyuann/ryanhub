import SwiftUI

// MARK: - DailyAffirmations Registration

extension DynamicModuleRegistry {
    static func registerDailyAffirmations() {
        shared.register(DynamicModuleDescriptor(
            id: "dailyAffirmations",
            toolkitId: "dailyAffirmations",
            displayName: "Daily Affirmations",
            shortName: "Affirmations",
            subtitle: "Nurture your mindset, one affirmation at a time",
            icon: "sparkles",
            iconColorName: "hubPrimaryLight",
            viewBuilder: { AnyView(DailyAffirmationsView()) },
            dataProviderType: DailyAffirmationsDataProvider.self
        ))
    }
}
