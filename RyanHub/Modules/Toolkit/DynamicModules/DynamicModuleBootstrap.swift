import Foundation

// MARK: - Dynamic Module Bootstrap

/// Auto-generated. Registers all dynamic modules at app startup.
extension DynamicModuleRegistry {
    static func bootstrapAll() {
        registerCaffeineTracker()
        registerCatCareTracker()
        registerCommuteTracker()
        registerDailyAffirmations()
        registerFocusSession()
        registerGratitudeJournal()
        registerGroceryList()
        registerHabitTracker()
        registerHydrationTracker()
        registerLearningTracker()
        registerMedicationTracker()
        registerMoodJournal()
        registerPeopleJournal()
        registerPlantCareTracker()
        registerReadingTracker()
        registerRecipeBox()
        registerScreenTimeTracker()
        registerSleepTracker()
        registerSpendingTracker()
        registerSubscriptionTracker()
    }
}
