import SwiftUI

// MARK: - MedicationTracker Medication Entry Sheet

struct MedicationTrackerMedicationEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: MedicationTrackerViewModel
    var onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var form: MedicationForm = .pill
    @State private var frequency: DoseFrequency = .onceDaily
    @State private var doseTimes: [Date] = [Date()]
    @State private var selectedColor: MedicationColor = .blue
    @State private var instructions: String = ""
    @State private var supplyCount: Int = 30
    @State private var isActive: Bool = true

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Medication",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                let entry = MedicationTrackerEntry(
                    name: name.trimmingCharacters(in: .whitespaces),
                    dosage: dosage.trimmingCharacters(in: .whitespaces),
                    form: form,
                    frequency: frequency,
                    primaryTime: doseTimes.first ?? Date(),
                    color: selectedColor,
                    instructions: instructions.trimmingCharacters(in: .whitespaces),
                    supplyCount: supplyCount,
                    isActive: isActive
                )
                Task { await viewModel.addEntry(entry) }
                onSave?()
                dismiss()
            }
        ) {
            // MARK: - Name

            EntryFormSection(title: "Medication Name") {
                HubTextField(placeholder: "Medication name", text: $name)
            }

            // MARK: - Dosage

            EntryFormSection(title: "Dosage") {
                HubTextField(placeholder: "e.g. 10mg", text: $dosage)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HubLayout.itemSpacing) {
                        ForEach(DosageSuggestion.commonDosages, id: \.self) { suggestion in
                            Button {
                                dosage = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.hubCaption)
                                    .foregroundStyle(dosage == suggestion ? .white : AdaptiveColors.textSecondary(for: colorScheme))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        dosage == suggestion
                                            ? Color.hubPrimary
                                            : AdaptiveColors.surfaceSecondary(for: colorScheme)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            // MARK: - Form

            EntryFormSection(title: "Form") {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: HubLayout.itemSpacing)
                ], spacing: HubLayout.itemSpacing) {
                    ForEach(MedicationForm.allCases) { medForm in
                        Button {
                            form = medForm
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: medForm.icon)
                                    .font(.title3)
                                Text(medForm.displayName)
                                    .font(.hubCaption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(form == medForm ? .white : AdaptiveColors.textSecondary(for: colorScheme))
                            .background(
                                form == medForm
                                    ? Color.hubPrimary
                                    : AdaptiveColors.surfaceSecondary(for: colorScheme)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius))
                        }
                    }
                }
            }

            // MARK: - Frequency

            EntryFormSection(title: "Frequency") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(DoseFrequency.allCases) { freq in
                        Label(freq.displayName, systemImage: freq.icon)
                            .tag(freq)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.hubPrimary)
                .onChange(of: frequency) { _, newValue in
                    updateDoseTimes(for: newValue)
                }
            }

            // MARK: - Schedule Times

            if frequency.isScheduled {
                EntryFormSection(title: "Schedule") {
                    ForEach(doseTimes.indices, id: \.self) { index in
                        HStack {
                            Label("Dose \(index + 1)", systemImage: timeSlotIcon(for: doseTimes[index]))
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            DatePicker(
                                "",
                                selection: binding(for: index),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .tint(Color.hubPrimary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // MARK: - Color

            EntryFormSection(title: "Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(MedicationColor.allCases) { medColor in
                            Button {
                                selectedColor = medColor
                            } label: {
                                Circle()
                                    .fill(medColor.swiftUIColor)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white, lineWidth: selectedColor == medColor ? 3 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                selectedColor == medColor
                                                    ? medColor.swiftUIColor
                                                    : .clear,
                                                lineWidth: 2
                                            )
                                            .frame(width: 44, height: 44)
                                    )
                                    .scaleEffect(selectedColor == medColor ? 1.15 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: selectedColor)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Instructions

            EntryFormSection(title: "Instructions (Optional)") {
                HubTextField(placeholder: "e.g. Take with food", text: $instructions)
            }

            // MARK: - Supply

            EntryFormSection(title: "Supply Count") {
                VStack(spacing: HubLayout.itemSpacing) {
                    Stepper(value: $supplyCount, in: 0...999) {
                        HStack {
                            Text("\(supplyCount)")
                                .font(.hubHeading)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text(supplyCount == 1 ? "unit" : "units")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    HStack(spacing: HubLayout.itemSpacing) {
                        ForEach(DosageSuggestion.commonSupplyAmounts, id: \.self) { amount in
                            Button {
                                supplyCount += amount
                            } label: {
                                Text("+\(amount)")
                                    .font(.hubCaption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.hubPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.hubPrimary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius))
                            }
                        }
                    }
                }
            }

            // MARK: - Active Toggle

            EntryFormSection(title: "Status") {
                Toggle(isOn: $isActive) {
                    Label("Active", systemImage: isActive ? "checkmark.circle.fill" : "circle")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .tint(Color.hubPrimary)
            }
        }
    }

    // MARK: - Helpers

    private func updateDoseTimes(for freq: DoseFrequency) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let offsets = freq.defaultTimeOffsets

        if offsets.isEmpty {
            doseTimes = [Date()]
            return
        }

        doseTimes = offsets.map { offset in
            startOfDay.addingTimeInterval(TimeInterval(offset))
        }
    }

    private func binding(for index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard index < doseTimes.count else { return Date() }
                return doseTimes[index]
            },
            set: { newValue in
                guard index < doseTimes.count else { return }
                doseTimes[index] = newValue
            }
        )
    }

    private func timeSlotIcon(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.fill"
        }
    }
}