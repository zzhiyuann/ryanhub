import SwiftUI

struct PlantCareTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PlantCareTrackerViewModel
    var onSave: (() -> Void)?

    @State private var plantName: String = ""
    @State private var careType: CareType = .water
    @State private var waterAmount: WaterAmount = .moderate
    @State private var healthScore: Int = 3
    @State private var soilMoisture: SoilMoisture = .moist
    @State private var location: PlantLocation = .livingRoom
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()

    private var canSave: Bool { !plantName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        QuickEntrySheet(
            title: "Add Plant Care Tracker",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                let entry = PlantCareTrackerEntry(
                    id: UUID().uuidString,
                    date: formatter.string(from: selectedDate),
                    plantName: plantName.trimmingCharacters(in: .whitespaces),
                    careType: careType,
                    waterAmount: waterAmount,
                    healthScore: healthScore,
                    soilMoisture: soilMoisture,
                    location: location,
                    notes: notes.trimmingCharacters(in: .whitespaces)
                )
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {
            EntryFormSection(title: "Plant") {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.hubAccentGreen)
                        .frame(width: 20)
                    TextField("Plant name (required)", text: $plantName)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .textInputAutocapitalization(.words)
                }

                DatePicker(
                    "Date & Time",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Care Type") {
                Picker("Care Type", selection: $careType) {
                    ForEach(CareType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .tint(Color.hubPrimary)

                if careType == .water {
                    Picker("Water Amount", selection: $waterAmount) {
                        ForEach(WaterAmount.allCases) { amount in
                            Label(amount.displayName, systemImage: amount.icon).tag(amount)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.hubBody)
                }
            }

            EntryFormSection(title: "Conditions") {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    Text("Soil Moisture")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Picker("Soil Moisture", selection: $soilMoisture) {
                        ForEach(SoilMoisture.allCases) { moisture in
                            Label(moisture.displayName, systemImage: moisture.icon).tag(moisture)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .tint(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    Text("Location")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Picker("Location", selection: $location) {
                        ForEach(PlantLocation.allCases) { loc in
                            Label(loc.displayName, systemImage: loc.icon).tag(loc)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .tint(Color.hubPrimary)
                }
            }

            EntryFormSection(title: "Plant Health") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: healthScoreIcon)
                            .foregroundStyle(healthScoreColor)
                        Text("Health: \(healthScoreLabel)")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text("\(healthScore) / 5")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Stepper(value: $healthScore, in: 1...5) {
                        EmptyView()
                    }
                    .labelsHidden()
                }
            }

            EntryFormSection(title: "Notes") {
                TextField("Optional notes...", text: $notes, axis: .vertical)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(3...6)
            }
        }
    }

    private var healthScoreLabel: String {
        switch healthScore {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "\(healthScore)"
        }
    }

    private var healthScoreIcon: String {
        switch healthScore {
        case 1, 2: return "heart.slash.fill"
        case 3: return "heart.fill"
        case 4, 5: return "heart.circle.fill"
        default: return "heart"
        }
    }

    private var healthScoreColor: Color {
        switch healthScore {
        case 1, 2: return Color.hubAccentRed
        case 3: return Color.hubAccentYellow
        case 4, 5: return Color.hubAccentGreen
        default: return Color.hubPrimary
        }
    }
}