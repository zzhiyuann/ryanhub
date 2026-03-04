import SwiftUI

// MARK: - PomodoroFocus Registration

extension DynamicModuleRegistry {
    static func registerPomodoroFocus() {
        shared.register(DynamicModuleDescriptor(
            id: "pomodoroFocus",
            toolkitId: "pomodoroFocus",
            displayName: "Pomodoro Focus",
            shortName: "Pomodoro",
            subtitle: "Track focus sessions with tasks",
            icon: "timer",
            iconColorName: "hubAccentRed",
            viewBuilder: { AnyView(PomodoroFocusView()) },
            dataProviderType: PomodoroFocusDataProvider.self
        ))
    }
}
