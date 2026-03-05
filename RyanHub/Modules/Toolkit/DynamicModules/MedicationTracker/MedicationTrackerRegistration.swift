import SwiftUI

// MARK: - MedicationTracker Registration

extension DynamicModuleRegistry {
    static func registerMedicationTracker() {
        shared.register(DynamicModuleDescriptor(
            id: "medicationTracker",
            toolkitId: "medicationTracker",
            displayName: "Medication Tracker",
            shortName: "Meds",
            subtitle: "Track doses, schedules & adherence",
            icon: "pills.fill",
            iconColorName: "hubAccentRed",
            viewBuilder: { AnyView(MedicationTrackerView()) },
            dataProviderType: MedicationTrackerDataProvider.self
        ))
    }
}
