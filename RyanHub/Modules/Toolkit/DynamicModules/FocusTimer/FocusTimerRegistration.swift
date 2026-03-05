import SwiftUI

// MARK: - FocusTimer Registration

extension DynamicModuleRegistry {
    static func registerFocusTimer() {
        shared.register(DynamicModuleDescriptor(
            id: "focusTimer",
            toolkitId: "focusTimer",
            displayName: "Focus Timer",
            shortName: "Focus",
            subtitle: "Pomodoro sessions & deep work tracking",
            icon: "timer",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(FocusTimerView()) },
            dataProviderType: FocusTimerDataProvider.self
        ))
    }
}
