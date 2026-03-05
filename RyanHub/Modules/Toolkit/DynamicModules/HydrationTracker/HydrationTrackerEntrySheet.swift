import SwiftUI

struct HydrationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HydrationTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputAmountml: Int = 250
    @State private var selectedBeveragetype: BeverageType = .water
    @State private var selectedContainerpreset: ContainerPreset = .small
    @State private var selectedTemperature: DrinkTemperature = .cold
    @State private var inputTimeconsumed: Date = Date()
    @State private var inputCaffeinated: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Hydration Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = HydrationTrackerEntry(amountMl: inputAmountml, beverageType: selectedBeveragetype, containerPreset: selectedContainerpreset, temperature: selectedTemperature, timeConsumed: inputTimeconsumed, caffeinated: inputCaffeinated, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Amount (ml)") {
                    Stepper("\(inputAmountml) ml", value: $inputAmountml, in: 50...2000, step: 50)
                }

                EntryFormSection(title: "Beverage Type") {
                    Picker("Beverage Type", selection: $selectedBeveragetype) {
                        ForEach(BeverageType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Container Size") {
                    Picker("Container Size", selection: $selectedContainerpreset) {
                        ForEach(ContainerPreset.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
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
                    DatePicker("Time", selection: $inputTimeconsumed, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Caffeinated") {
                    Toggle("Caffeinated", isOn: $inputCaffeinated)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
