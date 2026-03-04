import SwiftUI

// MARK: - LearningTracker Registration

extension DynamicModuleRegistry {
    static func registerLearningTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "learningTracker",
            toolkitId: "learningTracker",
            displayName: "Learning Tracker",
            shortName: "Learning",
            subtitle: "Track courses and skill progress",
            icon: "graduationcap.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(LearningTrackerView()) },
            dataProviderType: LearningTrackerDataProvider.self
        ))
    }
}
