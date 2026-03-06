import Foundation

// MARK: - Dynamic Module Bootstrap

/// Auto-generated. Registers all dynamic modules at app startup.
extension DynamicModuleRegistry {
    static func bootstrapAll() {
        registerHydrationTracker()
        // TODO: Fix broken code-gen artifacts in these modules
        // registerMedicationTracker()
        // registerSpendingTracker()
    }
}
