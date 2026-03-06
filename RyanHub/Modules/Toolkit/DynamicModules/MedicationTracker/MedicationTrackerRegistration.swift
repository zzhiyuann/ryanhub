import SwiftUI

// MARK: - MedicationTracker Registration

extension DynamicModuleRegistry {
    static func registerMedicationTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "medicationTracker",
            toolkitId: "medicationTracker",
            displayName: "Medication Tracker",
            shortName: "Meds",
            subtitle: "Track daily medications, doses & schedules",
            icon: "pills.fill",
            iconColorName: "hubAccentGreen",
            viewBuilder: { AnyView(MedicationTrackerView()) },
            dataProviderType: MedicationTrackerDataProvider.self
        ))
    }
}
