import SwiftUI

// MARK: - SleepLog Registration

extension DynamicModuleRegistry {
    static func registerSleepLog() {
        shared.register(DynamicModuleDescriptor(
            id: "sleepLog",
            toolkitId: "sleepLog",
            displayName: "Sleep Log",
            shortName: "Sleep",
            subtitle: "Track sleep hours, quality, and mood",
            icon: "bed.double.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(SleepLogView()) },
            dataProviderType: SleepLogDataProvider.self
        ))
    }
}
