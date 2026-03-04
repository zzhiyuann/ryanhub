import SwiftUI

// MARK: - CoffeeTracker Registration

extension DynamicModuleRegistry {
    static func registerCoffeeTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "coffeeTracker",
            toolkitId: "coffeeTracker",
            displayName: "Coffee Tracker",
            shortName: "Coffee",
            subtitle: "Track daily coffee & caffeine intake",
            icon: "cup.and.saucer.fill",
            iconColorName: "hubAccentYellow",
            viewBuilder: { AnyView(CoffeeTrackerView()) },
            dataProviderType: CoffeeTrackerDataProvider.self
        ))
    }
}
