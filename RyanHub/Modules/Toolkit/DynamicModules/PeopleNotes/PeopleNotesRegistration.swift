import SwiftUI

// MARK: - PeopleNotes Registration

extension DynamicModuleRegistry {
    static func registerPeopleNotes() {
        shared.register(DynamicModuleDescriptor(
            id: "peopleNotes",
            toolkitId: "peopleNotes",
            displayName: "People Notes",
            shortName: "People",
            subtitle: "Quick notes on people you meet",
            icon: "person.text.rectangle.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(PeopleNotesView()) },
            dataProviderType: PeopleNotesDataProvider.self
        ))
    }
}
