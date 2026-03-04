import SwiftUI

// MARK: - MoodJournal Registration

extension DynamicModuleRegistry {
    static func registerMoodJournal() {
        shared.register(DynamicModuleDescriptor(
            id: "moodJournal",
            toolkitId: "moodJournal",
            displayName: "Mood Journal",
            shortName: "Mood",
            subtitle: "Track your daily mood",
            icon: "face.smiling.fill",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(MoodJournalView()) },
            dataProviderType: MoodJournalDataProvider.self
        ))
    }
}
