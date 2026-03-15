import SwiftUI

// MARK: - Dashboard Registration

extension DynamicModuleRegistry {
    static func registerDashboard() {
        shared.register(DynamicModuleDescriptor(
            id: "dashboard",
            toolkitId: "dashboard",
            displayName: "Dashboard",
            shortName: "Dashboard",
            subtitle: "Projects, tasks, deadlines",
            icon: "square.grid.2x2.fill",
            iconColorName: "hubPrimary",
            viewBuilder: { AnyView(DashboardView()) },
            dataProviderType: DashboardDataProvider.self
        ))
    }
}
