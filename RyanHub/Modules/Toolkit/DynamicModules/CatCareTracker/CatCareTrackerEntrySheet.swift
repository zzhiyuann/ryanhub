import SwiftUI

struct CatCareTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CatCareTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedEntrytype: EntryType = .feeding
    @State private var selectedMealtype: CatMealType = .breakfast
    @State private var selectedFoodtype: FoodType = .wetFood
    @State private var inputPortionsize: Int = 1
    @State private var inputAppetitelevel: Double = 5
    @State private var selectedVisittype: VisitType = .checkup
    @State private var inputVetclinic: String = ""
    @State private var inputCost: Double = 0.0
    @State private var inputWeightkg: Double = 5
    @State private var inputMedicationgiven: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Cat Care Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CatCareTrackerEntry(entryType: selectedEntrytype, mealType: selectedMealtype, foodType: selectedFoodtype, portionSize: inputPortionsize, appetiteLevel: Int(inputAppetitelevel), visitType: selectedVisittype, vetClinic: inputVetclinic, cost: inputCost, weightKg: inputWeightkg, medicationGiven: inputMedicationgiven, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Entry Type") {
                    Picker("Entry Type", selection: $selectedEntrytype) {
                        ForEach(EntryType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Meal") {
                    Picker("Meal", selection: $selectedMealtype) {
                        ForEach(CatMealType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Food Type") {
                    Picker("Food Type", selection: $selectedFoodtype) {
                        ForEach(FoodType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Portions") {
                    Stepper("\(inputPortionsize) portions", value: $inputPortionsize, in: 0...9999)
                }

                EntryFormSection(title: "Appetite (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputAppetitelevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputAppetitelevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Visit Type") {
                    Picker("Visit Type", selection: $selectedVisittype) {
                        ForEach(VisitType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Clinic Name") {
                    HubTextField(placeholder: "Clinic Name", text: $inputVetclinic)
                }

                EntryFormSection(title: "Cost ($)") {
                    Stepper("\(inputCost) cost ($)", value: $inputCost, in: 0...9999)
                }

                EntryFormSection(title: "Weight (kg)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputWeightkg))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputWeightkg, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Medication Given") {
                    Toggle("Medication Given", isOn: $inputMedicationgiven)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
