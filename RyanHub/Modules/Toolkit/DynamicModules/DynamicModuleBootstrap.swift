import Foundation

// MARK: - Dynamic Module Bootstrap

/// Auto-generated. Registers all dynamic modules at app startup.
extension DynamicModuleRegistry {
    static func bootstrapAll() {
        registerHabitTracker()
        registerHydrationTracker()
        registerMedicationTracker()
        registerMoodJournal()
        registerReadingTracker()
        registerSleepTracker()
        registerSpendingTracker()
    }
}
