import SwiftUI

struct CoffeeTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CoffeeTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedDrinktype: CoffeeDrinkType = .espresso
    @State private var selectedCupsize: CoffeeCupSize = .small
    @State private var inputCaffeinemg: Int = 1
    @State private var inputTime: Date = Date()
    @State private var inputIsdecaf: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Coffee Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = CoffeeTrackerEntry(drinkType: selectedDrinktype, cupSize: selectedCupsize, caffeineMg: inputCaffeinemg, time: inputTime, isDecaf: inputIsdecaf, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Drink Type") {
                    Picker("Drink Type", selection: $selectedDrinktype) {
                        ForEach(CoffeeDrinkType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Size") {
                    Picker("Size", selection: $selectedCupsize) {
                        ForEach(CoffeeCupSize.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Caffeine (mg)") {
                    Stepper("\(inputCaffeinemg) caffeine (mg)", value: $inputCaffeinemg, in: 0...9999)
                }

                EntryFormSection(title: "Time") {
                    DatePicker("Time", selection: $inputTime, displayedComponents: .hourAndMinute)
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
