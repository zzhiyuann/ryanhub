import SwiftUI

struct PlantCareTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PlantCareTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputPlantname: String = ""
    @State private var selectedCaretype: CareType = .watering
    @State private var selectedWateramount: WaterAmount = .light
    @State private var inputHealthrating: Double = 5
    @State private var selectedLocation: PlantLocation = .livingRoom
    @State private var inputUsedfertilizer: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Plant Care Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = PlantCareTrackerEntry(plantName: inputPlantname, careType: selectedCaretype, waterAmount: selectedWateramount, healthRating: Int(inputHealthrating), location: selectedLocation, usedFertilizer: inputUsedfertilizer, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Plant Name") {
                    HubTextField(placeholder: "Plant Name", text: $inputPlantname)
                }

                EntryFormSection(title: "Care Type") {
                    Picker("Care Type", selection: $selectedCaretype) {
                        ForEach(CareType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Water Amount") {
                    Picker("Water Amount", selection: $selectedWateramount) {
                        ForEach(WaterAmount.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Health Rating (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputHealthrating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputHealthrating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Location") {
                    Picker("Location", selection: $selectedLocation) {
                        ForEach(PlantLocation.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Added Fertilizer") {
                    Toggle("Added Fertilizer", isOn: $inputUsedfertilizer)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Observations") {
                    HubTextField(placeholder: "Observations", text: $inputNotes)
                }
        }
    }
}
