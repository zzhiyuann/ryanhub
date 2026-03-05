import SwiftUI

struct CaffeineTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CaffeineTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedDrinktype: DrinkType = .espresso
    @State private var selectedSize: DrinkSize = .small
    @State private var inputCaffeinemg: Int = 1
    @State private var inputShots: Int = 1
    @State private var inputTime: Date = Date()
    @State private var inputCost: Double = 0.0
    @State private var inputIsdecaf: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Caffeine Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CaffeineTrackerEntry(drinkType: selectedDrinktype, size: selectedSize, caffeineMg: inputCaffeinemg, shots: inputShots, time: inputTime, cost: inputCost, isDecaf: inputIsdecaf, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Drink") {
                    Picker("Drink", selection: $selectedDrinktype) {
                        ForEach(DrinkType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Size") {
                    Picker("Size", selection: $selectedSize) {
                        ForEach(DrinkSize.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Caffeine (mg)") {
                    Stepper("\(inputCaffeinemg) caffeine (mg)", value: $inputCaffeinemg, in: 0...9999)
                }

                EntryFormSection(title: "Espresso Shots") {
                    Stepper("\(inputShots) espresso shots", value: $inputShots, in: 0...9999)
                }

                EntryFormSection(title: "Time") {
                    DatePicker("Time", selection: $inputTime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Cost ($)") {
                    Stepper("\(inputCost) cost ($)", value: $inputCost, in: 0...9999)
                }

                EntryFormSection(title: "Decaf") {
                    Toggle("Decaf", isOn: $inputIsdecaf)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
