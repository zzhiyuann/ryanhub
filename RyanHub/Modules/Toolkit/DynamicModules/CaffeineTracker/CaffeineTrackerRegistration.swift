import SwiftUI

// MARK: - CaffeineTracker Registration

extension DynamicModuleRegistry {
    static func registerCaffeineTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "caffeineTracker",
            toolkitId: "caffeineTracker",
            displayName: "Caffeine Tracker",
            shortName: "Caffeine",
            subtitle: "Track cups, caffeine & timing",
            icon: "cup.and.saucer.fill",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(CaffeineTrackerView()) },
            dataProviderType: CaffeineTrackerDataProvider.self
        ))
    }
}
