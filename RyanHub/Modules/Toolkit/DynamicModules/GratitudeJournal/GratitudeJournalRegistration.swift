import SwiftUI

// MARK: - GratitudeJournal Registration

extension DynamicModuleRegistry {
    static func registerGratitudeJournal() {
        shared.register(DynamicModuleDescriptor(
            id: "gratitudeJournal",
            toolkitId: "gratitudeJournal",
            displayName: "Gratitude Journal",
            shortName: "Gratitude",
            subtitle: "3 things you're grateful for, every day",
            icon: "heart.text.clipboard",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(GratitudeJournalView()) },
            dataProviderType: GratitudeJournalDataProvider.self
        ))
    }
}
