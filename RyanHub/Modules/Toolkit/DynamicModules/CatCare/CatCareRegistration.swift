import SwiftUI

// MARK: - CatCare Registration

extension DynamicModuleRegistry {
    static func registerCatCare() {
        shared.register(DynamicModuleDescriptor(
            id: "catCare",
            toolkitId: "catCare",
            displayName: "Cat Care",
            shortName: "Cat",
            subtitle: "Track feeding times and vet visits",
            icon: "pawprint.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(CatCareView()) },
            dataProviderType: CatCareDataProvider.self
        ))
    }
}
