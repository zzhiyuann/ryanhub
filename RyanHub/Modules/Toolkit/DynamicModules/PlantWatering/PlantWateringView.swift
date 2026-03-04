import SwiftUI

struct PlantWateringView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = PlantWateringViewModel()
    @State private var inputPlantname: String = ""
    @State private var inputWateringintervaldays: String = ""
    @State private var inputLastwatereddate: String = ""
    @State private var inputNextwateringdate: String = ""
    @State private var inputLocation: String = ""
    @State private var inputWateramountml: String = ""
    @State private var inputSunlight: String = ""
    @State private var inputIsoverdue: String = ""
    @State private var inputNote: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plant Watering")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("\(viewModel.entries.count) entries")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                }

                // Add entry form
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Add Entry")
                    TextField("Plant Name", text: $inputPlantname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Watering Interval (days)", text: $inputWateringintervaldays)
                        .textFieldStyle(.roundedBorder)
                    TextField("Last Watered", text: $inputLastwatereddate)
                        .textFieldStyle(.roundedBorder)
                    TextField("Next Watering", text: $inputNextwateringdate)
                        .textFieldStyle(.roundedBorder)
                    TextField("Location", text: $inputLocation)
                        .textFieldStyle(.roundedBorder)
                    TextField("Water Amount (ml)", text: $inputWateramountml)
                        .textFieldStyle(.roundedBorder)
                    TextField("Sunlight Level", text: $inputSunlight)
                        .textFieldStyle(.roundedBorder)
                    TextField("Overdue", text: $inputIsoverdue)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = PlantWateringEntry(plantName: inputPlantname, wateringIntervalDays: Int(inputWateringintervaldays) ?? 0, lastWateredDate: inputLastwatereddate, nextWateringDate: inputNextwateringdate, location: inputLocation.isEmpty ? nil : inputLocation, waterAmountMl: Double(inputWateramountml), sunlight: inputSunlight.isEmpty ? nil : inputSunlight, isOverdue: inputIsoverdue == "true", note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputPlantname = ""
                            inputWateringintervaldays = ""
                            inputLastwatereddate = ""
                            inputNextwateringdate = ""
                            inputLocation = ""
                            inputWateramountml = ""
                            inputSunlight = ""
                            inputIsoverdue = ""
                            inputNote = ""
                        }
                    } label: {
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: HubLayout.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .fill(Color.hubPrimary)
                            )
                    }
                }
                .padding(HubLayout.standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                )

                // Entries list
                if !viewModel.entries.isEmpty {
                    VStack(spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Recent Entries")
                        ForEach(viewModel.entries.reversed()) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("Plant Name: \(entry.plantName)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Watering Interval (days): \(entry.wateringIntervalDays)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Last Watered: \(entry.lastWateredDate)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Next Watering: \(entry.nextWateringDate)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.location { Text("Location: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.waterAmountMl { Text("Water Amount (ml): \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.sunlight { Text("Sunlight Level: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                Text("Overdue: \(entry.isOverdue)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.note { Text("Notes: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                }
                                Spacer()
                                Button {
                                    Task { await viewModel.deleteEntry(entry) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.hubAccentRed)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AdaptiveColors.surface(for: colorScheme))
                            )
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
    }
}
