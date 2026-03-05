import SwiftUI

struct MedicationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MedicationTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputMedicationname: String = ""
    @State private var inputDosageamount: Double = 1.0
    @State private var selectedDosageunit: DosageUnit = .mg
    @State private var selectedMedicationform: MedicationForm = .pill
    @State private var inputQuantity: Int = 1
    @State private var inputScheduledtime: Date = Date()
    @State private var selectedAdherencestatus: AdherenceStatus = .onTime
    @State private var inputWithfood: Bool = false
    @State private var inputSideeffectnoted: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Medication Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = MedicationTrackerEntry(medicationName: inputMedicationname, dosageAmount: inputDosageamount, dosageUnit: selectedDosageunit, medicationForm: selectedMedicationform, quantity: inputQuantity, scheduledTime: inputScheduledtime, adherenceStatus: selectedAdherencestatus, withFood: inputWithfood, sideEffectNoted: inputSideeffectnoted, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Medication Name") {
                    HubTextField(placeholder: "Medication Name", text: $inputMedicationname)
                }

                EntryFormSection(title: "Dosage Amount") {
                    Stepper(String(format: "%.1f dosage", inputDosageamount), value: $inputDosageamount, in: 0...1000, step: 0.5)
                }

                EntryFormSection(title: "Dosage Unit") {
                    Picker("Dosage Unit", selection: $selectedDosageunit) {
                        ForEach(DosageUnit.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Form") {
                    Picker("Form", selection: $selectedMedicationform) {
                        ForEach(MedicationForm.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Quantity Taken") {
                    Stepper("\(inputQuantity) quantity taken", value: $inputQuantity, in: 0...9999)
                }

                EntryFormSection(title: "Scheduled Time") {
                    DatePicker("Scheduled Time", selection: $inputScheduledtime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Status") {
                    Picker("Status", selection: $selectedAdherencestatus) {
                        ForEach(AdherenceStatus.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Taken with Food") {
                    Toggle("Taken with Food", isOn: $inputWithfood)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Side Effect Noted") {
                    Toggle("Side Effect Noted", isOn: $inputSideeffectnoted)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
