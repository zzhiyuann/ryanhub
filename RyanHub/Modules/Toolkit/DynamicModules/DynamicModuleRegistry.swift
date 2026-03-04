import SwiftUI

// MARK: - Dynamic Module Registry

/// A runtime registry for dynamically generated toolkit modules.
/// Unlike the hardcoded `ToolkitPlugin` enum, dynamic modules self-register
/// via `DynamicModuleBootstrap.bootstrapAll()` at app startup.
@Observable @MainActor
final class DynamicModuleRegistry {
    static let shared = DynamicModuleRegistry()

    /// All registered dynamic modules, keyed by toolkitId.
    var modules: [String: DynamicModuleDescriptor] = [:]

    /// Ordered list of module IDs for consistent display ordering.
    var moduleOrder: [String] = []

    private init() {}

    func register(_ descriptor: DynamicModuleDescriptor) {
        modules[descriptor.toolkitId] = descriptor
        if !moduleOrder.contains(descriptor.toolkitId) {
            moduleOrder.append(descriptor.toolkitId)
        }
    }

    /// Ordered descriptors for display in the toolkit grid.
    var orderedModules: [DynamicModuleDescriptor] {
        moduleOrder.compactMap { modules[$0] }
    }
}

// MARK: - Dynamic Module Descriptor

/// Describes a dynamically generated module with all metadata needed
/// for display and integration.
struct DynamicModuleDescriptor: Identifiable {
    let id: String
    let toolkitId: String
    let displayName: String
    let shortName: String
    let subtitle: String
    let icon: String
    let iconColorName: String
    let viewBuilder: @MainActor () -> AnyView
    let dataProviderType: any ToolkitDataProvider.Type

    /// Resolve the icon color name to an actual Color.
    var iconColor: Color {
        switch iconColorName {
        case "hubPrimary": return .hubPrimary
        case "hubPrimaryLight": return .hubPrimaryLight
        case "hubAccentGreen": return .hubAccentGreen
        case "hubAccentRed": return .hubAccentRed
        case "hubAccentYellow": return .hubAccentYellow
        default: return .hubPrimary
        }
    }
}
