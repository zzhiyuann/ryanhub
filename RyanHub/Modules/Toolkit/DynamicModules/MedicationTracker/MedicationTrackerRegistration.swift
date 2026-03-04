import SwiftUI

// MARK: - MedicationTracker Registration

extension DynamicModuleRegistry {
    static func registerMedicationTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "medicationTracker",
            toolkitId: "medicationTracker",
            displayName: "Medication Tracker",
            shortName: "Meds",
            subtitle: "Track daily medications and doses",
            icon: "pill.fill",
            iconColorName: "hubAccentRed",
            viewBuilder: { AnyView(MedicationTrackerView()) },
            dataProviderType: MedicationTrackerDataProvider.self
        ))
    }
}
