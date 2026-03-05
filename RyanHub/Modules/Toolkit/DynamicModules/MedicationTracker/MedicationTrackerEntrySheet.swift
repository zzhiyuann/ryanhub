import SwiftUI

struct MedicationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MedicationTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputMedicationname: String = ""
    @State private var inputDosageamount: Double = 0.0
    @State private var selectedDosageunit: DosageUnit = .mg
    @State private var selectedTimeslot: TimeSlot = .morning
    @State private var inputTaken: Bool = false
    @State private var selectedFeeling: PostDoseFeeling = .great
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Medication Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = MedicationTrackerEntry(medicationName: inputMedicationname, dosageAmount: inputDosageamount, dosageUnit: selectedDosageunit, timeSlot: selectedTimeslot, taken: inputTaken, feeling: selectedFeeling, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Medication") {
                    HubTextField(placeholder: "Medication", text: $inputMedicationname)
                }

                EntryFormSection(title: "Dosage Amount") {
                    Stepper("\(inputDosageamount) dosage amount", value: $inputDosageamount, in: 0...9999)
                }

                EntryFormSection(title: "Unit") {
                    Picker("Unit", selection: $selectedDosageunit) {
                        ForEach(DosageUnit.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Time of Day") {
                    Picker("Time of Day", selection: $selectedTimeslot) {
                        ForEach(TimeSlot.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Taken") {
                    Toggle("Taken", isOn: $inputTaken)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "How You Feel") {
                    Picker("How You Feel", selection: $selectedFeeling) {
                        ForEach(PostDoseFeeling.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Notes / Side Effects") {
                    HubTextField(placeholder: "Notes / Side Effects", text: $inputNotes)
                }
        }
    }
}
