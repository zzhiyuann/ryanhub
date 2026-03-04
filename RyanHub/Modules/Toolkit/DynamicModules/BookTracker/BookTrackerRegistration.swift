import SwiftUI

// MARK: - BookTracker Registration

extension DynamicModuleRegistry {
    static func registerBookTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "bookTracker",
            toolkitId: "bookTracker",
            displayName: "Book Tracker",
            shortName: "Books",
            subtitle: "Track reading progress and notes",
            icon: "books.vertical.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(BookTrackerView()) },
            dataProviderType: BookTrackerDataProvider.self
        ))
    }
}
