import SwiftUI

// MARK: - DailyGratitude Registration

extension DynamicModuleRegistry {
    static func registerDailyGratitude() {
        shared.register(DynamicModuleDescriptor(
            id: "dailyGratitude",
            toolkitId: "dailyGratitude",
            displayName: "Daily Gratitude",
            shortName: "Gratitude",
            subtitle: "Log 3 things you're grateful for",
            icon: "heart.text.square.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(DailyGratitudeView()) },
            dataProviderType: DailyGratitudeDataProvider.self
        ))
    }
}
