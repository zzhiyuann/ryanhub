import SwiftUI

// MARK: - LearningTracker Registration

extension DynamicModuleRegistry {
    static func registerLearningTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "learningTracker",
            toolkitId: "learningTracker",
            displayName: "Learning Tracker",
            shortName: "Learning",
            subtitle: "Track courses, skills & study sessions",
            icon: "book.and.wrench.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(LearningTrackerView()) },
            dataProviderType: LearningTrackerDataProvider.self
        ))
    }
}
