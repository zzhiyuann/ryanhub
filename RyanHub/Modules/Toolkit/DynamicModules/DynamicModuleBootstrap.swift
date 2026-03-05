import Foundation

// MARK: - Dynamic Module Bootstrap

/// Auto-generated. Registers all dynamic modules at app startup.
extension DynamicModuleRegistry {
    static func bootstrapAll() {
        registerCaffeineTracker()
        registerCatCareTracker()
        registerCommuteTracker()
        registerDailyAffirmations()
        registerFocusTimer()
        registerGratitudeJournal()
        registerGroceryList()
        registerHabitTracker()
        registerHydrationTracker()
        registerLearningTracker()
        registerMedicationTracker()
        registerMoodJournal()
        registerPeopleNotes()
        registerPlantCareTracker()
        registerReadingTracker()
        registerRecipeBox()
        registerScreenTimeTracker()
        registerSleepTracker()
        registerSpendingTracker()
        registerSubscriptionTracker()
    }
}
