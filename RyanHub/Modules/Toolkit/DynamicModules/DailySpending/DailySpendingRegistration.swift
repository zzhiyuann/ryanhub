import SwiftUI

// MARK: - DailySpending Registration

extension DynamicModuleRegistry {
    static func registerDailySpending() {
        shared.register(DynamicModuleDescriptor(
            id: "dailySpending",
            toolkitId: "dailySpending",
            displayName: "Daily Spending",
            shortName: "Spending",
            subtitle: "Track daily expenses by category",
            icon: "creditcard.fill",
            iconColorName: "hubAccentRed",
            viewBuilder: { AnyView(DailySpendingView()) },
            dataProviderType: DailySpendingDataProvider.self
        ))
    }
}
