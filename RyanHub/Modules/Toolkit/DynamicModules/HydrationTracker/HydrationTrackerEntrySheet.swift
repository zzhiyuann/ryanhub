import SwiftUI

struct HydrationTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: HydrationTrackerViewModel
    var onSave: (() -> Void)?

    @State private var selectedDate: Date = Date()
    @State private var amountOz: Double = 8.0
    @State private var containerType: ContainerType = .smallGlass
    @State private var beverageType: BeverageType = .water
    @State private var note: String = ""

    private var effectiveOz: Double {
        amountOz * beverageType.hydrationCoefficient
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Hydration Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: saveEntry
        ) {
            EntryFormSection(title: "Beverage") {
                Picker("Beverage Type", selection: $beverageType) {
                    ForEach(BeverageType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)

                if beverageType.hydrationCoefficient < 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("\(beverageType.displayName) counts as \(beverageType.coefficientLabel)")
                    }
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            EntryFormSection(title: "Container") {
                Picker("Container Type", selection: $containerType) {
                    ForEach(ContainerType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: containerType) { _, newType in
                    if newType != .custom {
                        amountOz = newType.defaultOz
                    }
                }
            }

            EntryFormSection(title: "Amount") {
                VStack(spacing: HubLayout.itemSpacing) {
                    if containerType == .custom {
                        HStack {
                            Text("Amount")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                            Text(String(format: "%.0f oz", amountOz))
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        }
                        Slider(value: $amountOz, in: 1...128, step: 1)
                            .tint(Color.hubPrimary)
                    } else {
                        Stepper(
                            value: $amountOz,
                            in: 1...128,
                            step: 1
                        ) {
                            HStack {
                                Text("Amount")
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Spacer()
                                Text(String(format: "%.0f oz", amountOz))
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                        }
                    }

                    if beverageType.hydrationCoefficient < 1.0 {
                        HStack {
                            Spacer()
                            Text(String(format: "≈ %.1f oz effective hydration", effectiveOz))
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }
            }

            EntryFormSection(title: "Time") {
                DatePicker(
                    "Date & Time",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }

            EntryFormSection(title: "Note (Optional)") {
                TextField("Add a note...", text: $note)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    private func saveEntry() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var entry = HydrationTrackerEntry()
        entry.date = formatter.string(from: selectedDate)
        entry.amountOz = amountOz
        entry.containerType = containerType
        entry.beverageType = beverageType
        entry.note = note

        Task { await viewModel.addEntry(entry) }
        onSave?()
    }
}