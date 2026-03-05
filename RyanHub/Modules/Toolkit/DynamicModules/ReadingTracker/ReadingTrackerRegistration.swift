import SwiftUI

// MARK: - ReadingTracker Registration

extension DynamicModuleRegistry {
    static func registerReadingTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "readingTracker",
            toolkitId: "readingTracker",
            displayName: "Reading Tracker",
            shortName: "Reading",
            subtitle: "Track books, reading sessions & insights",
            icon: "book.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(ReadingTrackerView()) },
            dataProviderType: ReadingTrackerDataProvider.self
        ))
    }
}
