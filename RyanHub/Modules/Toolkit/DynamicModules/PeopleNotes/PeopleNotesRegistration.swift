import SwiftUI

// MARK: - PeopleNotes Registration

extension DynamicModuleRegistry {
    static func registerPeopleNotes() {
        shared.register(DynamicModuleDescriptor(
            id: "peopleNotes",
            toolkitId: "peopleNotes",
            displayName: "People Notes",
            shortName: "People",
            subtitle: "Remember everyone you meet",
            icon: "person.text.rectangle",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(PeopleNotesView()) },
            dataProviderType: PeopleNotesDataProvider.self
        ))
    }
}
