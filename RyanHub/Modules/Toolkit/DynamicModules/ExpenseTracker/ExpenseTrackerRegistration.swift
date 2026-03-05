import SwiftUI

// MARK: - ExpenseTracker Registration

extension DynamicModuleRegistry {
    static func registerExpenseTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "expenseTracker",
            toolkitId: "expenseTracker",
            displayName: "Expense Tracker",
            shortName: "Expenses",
            subtitle: "Track spending, set budgets, gain insights",
            icon: "creditcard.and.123",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(ExpenseTrackerView()) },
            dataProviderType: ExpenseTrackerDataProvider.self
        ))
    }
}
