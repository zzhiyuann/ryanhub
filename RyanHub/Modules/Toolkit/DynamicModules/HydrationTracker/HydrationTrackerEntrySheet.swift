import SwiftUI

struct HydrationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HydrationTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputAmountml: Int = 1
    @State private var selectedBeveragetype: BeverageType = .water
    @State private var selectedContainersize: ContainerSize = .sip
    @State private var inputHydrationfactor: Double = 5
    @State private var selectedTemperature: BeverageTemp = .cold
    @State private var inputNote: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Hydration Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = HydrationTrackerEntry(amountMl: inputAmountml, beverageType: selectedBeveragetype, containerSize: selectedContainersize, hydrationFactor: inputHydrationfactor, temperature: selectedTemperature, note: inputNote)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Amount (ml)") {
                    Stepper("\(inputAmountml) amount (ml)", value: $inputAmountml, in: 0...9999)
                }

                EntryFormSection(title: "Beverage") {
                    Picker("Beverage", selection: $selectedBeveragetype) {
                        ForEach(BeverageType.allCases) { item in
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

                EntryFormSection(title: "Hydration Factor") {
                    VStack {
                        HStack {
                            Text("\(Int(inputHydrationfactor))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputHydrationfactor, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Temperature") {
                    Picker("Temperature", selection: $selectedTemperature) {
                        ForEach(BeverageTemp.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Note") {
                    HubTextField(placeholder: "Note", text: $inputNote)
                }
        }
    }
}
