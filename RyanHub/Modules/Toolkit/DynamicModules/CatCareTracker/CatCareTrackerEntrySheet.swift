import SwiftUI

struct CatCareTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CatCareTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedEventtype: CareEventType = .feeding
    @State private var selectedFeedtype: FeedType = .wetFood
    @State private var inputPortioncount: Int = 1
    @State private var selectedVetvisittype: VetVisitType = .checkup
    @State private var selectedMedicationtype: MedicationType = .fleaTick
    @State private var inputWeightgrams: Int = 1
    @State private var selectedMood: CatMood = .playful
    @State private var inputCostcents: Int = 1
    @State private var inputEventtime: Date = Date()
    @State private var inputWaseaten: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Cat Care Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CatCareTrackerEntry(eventType: selectedEventtype, feedType: selectedFeedtype, portionCount: inputPortioncount, wasEaten: inputWaseaten, vetVisitType: selectedVetvisittype, costCents: inputCostcents, medicationType: selectedMedicationtype, weightGrams: inputWeightgrams, mood: selectedMood, eventTime: inputEventtime, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Event Type") {
                    Picker("Event Type", selection: $selectedEventtype) {
                        ForEach(CareEventType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Food Type") {
                    Picker("Food Type", selection: $selectedFeedtype) {
                        ForEach(FeedType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Portions") {
                    Stepper("\(inputPortioncount) portions", value: $inputPortioncount, in: 0...9999)
                }

                EntryFormSection(title: "Visit Type") {
                    Picker("Visit Type", selection: $selectedVetvisittype) {
                        ForEach(VetVisitType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Medication") {
                    Picker("Medication", selection: $selectedMedicationtype) {
                        ForEach(MedicationType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Weight (g)") {
                    Stepper("\(inputWeightgrams) weight (g)", value: $inputWeightgrams, in: 0...9999)
                }

                EntryFormSection(title: "Mood") {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(CatMood.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Cost ($)") {
                    Stepper("\(inputCostcents) cost ($)", value: $inputCostcents, in: 0...9999)
                }

                EntryFormSection(title: "Time") {
                    DatePicker("Time", selection: $inputEventtime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Finished Meal") {
                    Toggle("Finished Meal", isOn: $inputWaseaten)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
