import SwiftUI

struct PlantCareTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PlantCareTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputPlantname: String = ""
    @State private var selectedLocation: PlantLocation = .livingRoom
    @State private var selectedWateramount: WaterAmount = .lightSplash
    @State private var inputHealthrating: Double = 5
    @State private var inputFertilized: Bool = false
    @State private var inputMisted: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Plant Care Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = PlantCareTrackerEntry(plantName: inputPlantname, location: selectedLocation, waterAmount: selectedWateramount, healthRating: Int(inputHealthrating), fertilized: inputFertilized, misted: inputMisted, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Plant Name") {
                    HubTextField(placeholder: "Plant Name", text: $inputPlantname)
                }

                EntryFormSection(title: "Location") {
                    Picker("Location", selection: $selectedLocation) {
                        ForEach(PlantLocation.allCases) { item in
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

                EntryFormSection(title: "Health Rating (1–5)") {
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

                EntryFormSection(title: "Fertilized") {
                    Toggle("Fertilized", isOn: $inputFertilized)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Misted") {
                    Toggle("Misted", isOn: $inputMisted)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
