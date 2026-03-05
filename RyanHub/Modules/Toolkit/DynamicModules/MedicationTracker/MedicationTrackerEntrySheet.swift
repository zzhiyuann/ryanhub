import SwiftUI

struct MedicationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MedicationTrackerViewModel
    var onSave: (() -> Void)?

    @State private var medicationName: String = ""
    @State private var dosageAmount: Double = 1.0
    @State private var dosageUnit: DosageUnit = .mg
    @State private var medicationForm: MedicationForm = .pill
    @State private var timeOfDay: MedicationTimeOfDay = .morning
    @State private var scheduledTime: Date = Date()
    @State private var status: DoseStatus = .taken
    @State private var withFood: Bool = false
    @State private var sideEffects: String = ""
    @State private var notes: String = ""

    private var canSave: Bool {
        !medicationName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var dosageDisplayString: String {
        let amount = dosageAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(dosageAmount))
            : String(format: "%.1f", dosageAmount)
        return "\(amount) \(dosageUnit.displayName)"
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Medication Tracker",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                saveEntry()
            }
        ) {
            EntryFormSection(title: "Medication") {
                VStack(spacing: HubLayout.itemSpacing) {
                    TextField("Medication name", text: $medicationName)
                        .textFieldStyle(.roundedBorder)

                    Picker("Form", selection: $medicationForm) {
                        ForEach(MedicationForm.allCases) { form in
                            Label(form.displayName, systemImage: form.icon)
                                .tag(form)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            EntryFormSection(title: "Dosage") {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    HStack {
                        Text("Amount")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Spacer()
                        Text(dosageDisplayString)
                            .font(.hubBody)
                            .foregroundStyle(Color.hubPrimary)
                            .fontWeight(.semibold)
                    }

                    Slider(value: $dosageAmount, in: 0.5...50.0, step: 0.5)
                        .tint(Color.hubPrimary)

                    Picker("Unit", selection: $dosageUnit) {
                        ForEach(DosageUnit.allCases) { unit in
                            Label(unit.displayName, systemImage: unit.icon)
                                .tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            EntryFormSection(title: "Schedule") {
                VStack(spacing: HubLayout.itemSpacing) {
                    Picker("Time of Day", selection: $timeOfDay) {
                        ForEach(MedicationTimeOfDay.allCases) { time in
                            Label(time.displayName, systemImage: time.icon)
                                .tag(time)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DatePicker(
                        "Scheduled Time",
                        selection: $scheduledTime,
                        displayedComponents: .hourAndMinute
                    )
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
            }

            EntryFormSection(title: "Dose Status") {
                Picker("Status", selection: $status) {
                    ForEach(DoseStatus.allCases) { s in
                        Label(s.displayName, systemImage: s.icon)
                            .tag(s)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            EntryFormSection(title: "Details") {
                Toggle("Taken with Food", isOn: $withFood)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .tint(Color.hubAccentGreen)
            }

            EntryFormSection(title: "Side Effects & Notes") {
                VStack(spacing: HubLayout.itemSpacing) {
                    TextField("Side effects (optional)", text: $sideEffects)
                        .textFieldStyle(.roundedBorder)

                    TextField("Notes (optional)", text: $notes)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private func saveEntry() {
        var entry = MedicationTrackerEntry()
        entry.medicationName = medicationName
        entry.dosageAmount = dosageAmount
        entry.dosageUnit = dosageUnit
        entry.medicationForm = medicationForm
        entry.timeOfDay = timeOfDay
        entry.scheduledTime = scheduledTime
        entry.status = status
        entry.withFood = withFood
        entry.sideEffects = sideEffects
        entry.notes = notes
        Task { await viewModel.addEntry(entry) }
        onSave?()
    }
}