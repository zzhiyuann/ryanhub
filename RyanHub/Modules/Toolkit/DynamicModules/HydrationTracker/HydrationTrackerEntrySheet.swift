import SwiftUI

struct HydrationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HydrationTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputAmount: Int = 1
    @State private var selectedDrinktype: DrinkType = .water
    @State private var selectedContainersize: ContainerSize = .sip
    @State private var inputCaffeinated: Bool = false
    @State private var selectedTemperature: DrinkTemperature = .cold
    @State private var inputTime: Date = Date()
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Hydration Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = HydrationTrackerEntry(amount: inputAmount, drinkType: selectedDrinktype, containerSize: selectedContainersize, caffeinated: inputCaffeinated, temperature: selectedTemperature, time: inputTime, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Amount (ml)") {
                    Stepper("\(inputAmount) amount (ml)", value: $inputAmount, in: 0...9999)
                }

                EntryFormSection(title: "Drink Type") {
                    Picker("Drink Type", selection: $selectedDrinktype) {
                        ForEach(DrinkType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Container") {
                    Picker("Container", selection: $selectedContainersize) {
                        ForEach(ContainerSize.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Caffeinated") {
                    Toggle("Caffeinated", isOn: $inputCaffeinated)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Temperature") {
                    Picker("Temperature", selection: $selectedTemperature) {
                        ForEach(DrinkTemperature.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Time") {
                    DatePicker("Time", selection: $inputTime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
