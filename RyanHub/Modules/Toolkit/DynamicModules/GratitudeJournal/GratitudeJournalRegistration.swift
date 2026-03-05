import SwiftUI

// MARK: - GratitudeJournal Registration

extension DynamicModuleRegistry {
    static func registerGratitudeJournal() {
        shared.register(DynamicModuleDescriptor(
            id: "gratitudeJournal",
            toolkitId: "gratitudeJournal",
            displayName: "Gratitude Journal",
            shortName: "Gratitude",
            subtitle: "3 things to be thankful for, every day",
            icon: "sparkles",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(GratitudeJournalView()) },
            dataProviderType: GratitudeJournalDataProvider.self
        ))
    }
}
