import SwiftUI

// MARK: - PeopleJournal Registration

extension DynamicModuleRegistry {
    static func registerPeopleJournal() {
        shared.register(DynamicModuleDescriptor(
            id: "peopleJournal",
            toolkitId: "peopleJournal",
            displayName: "People Journal",
            shortName: "People",
            subtitle: "Remember everyone you meet",
            icon: "person.text.rectangle",
            iconColorName: "hubPrimaryLight",
            viewBuilder: { AnyView(PeopleJournalView()) },
            dataProviderType: PeopleJournalDataProvider.self
        ))
    }
}
