import SwiftUI

// MARK: - MoodJournal Registration

extension DynamicModuleRegistry {
    static func registerMoodJournal() {
        shared.register(DynamicModuleDescriptor(
            id: "moodJournal",
            toolkitId: "moodJournal",
            displayName: "Mood Journal",
            shortName: "Mood",
            subtitle: "Track your emotional wellbeing",
            icon: "face.smiling",
            iconColorName: "hubPrimaryLight",
            viewBuilder: { AnyView(MoodJournalView()) },
            dataProviderType: MoodJournalDataProvider.self
        ))
    }
}
