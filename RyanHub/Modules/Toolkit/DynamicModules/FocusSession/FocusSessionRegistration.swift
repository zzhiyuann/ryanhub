import SwiftUI

// MARK: - FocusSession Registration

extension DynamicModuleRegistry {
    static func registerFocusSession() {
        shared.register(DynamicModuleDescriptor(
            id: "focusSession",
            toolkitId: "focusSession",
            displayName: "Focus Sessions",
            shortName: "Focus",
            subtitle: "Track deep work & pomodoro sessions",
            icon: "brain.head.profile",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(FocusSessionView()) },
            dataProviderType: FocusSessionDataProvider.self
        ))
    }
}
