import SwiftUI

// MARK: - MoodJournal Registration

extension DynamicModuleRegistry {
    static func registerMoodJournal() {
        shared.register(DynamicModuleDescriptor(
            id: "moodJournal",
            toolkitId: "moodJournal",
            displayName: "Mood Journal",
            shortName: "Mood",
            subtitle: "Track emotions, discover patterns",
            icon: "brain.head.profile",
            iconColorName: "hubPrimaryLight",
            viewBuilder: { AnyView(MoodJournalView()) },
            dataProviderType: MoodJournalDataProvider.self
        ))
    }
}
