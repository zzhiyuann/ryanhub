import SwiftUI

// MARK: - FocusTimer Registration

extension DynamicModuleRegistry {
    static func registerFocusTimer() {
        shared.register(DynamicModuleDescriptor(
            id: "focusTimer",
            toolkitId: "focusTimer",
            displayName: "Focus Timer",
            shortName: "Focus",
            subtitle: "Track pomodoro sessions & deep work",
            icon: "brain.head.profile",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(FocusTimerView()) },
            dataProviderType: FocusTimerDataProvider.self
        ))
    }
}
