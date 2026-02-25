import SwiftUI

// MARK: - Weight Log View

/// Sheet for logging a new weight entry.
struct WeightLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: HealthViewModel

    @State private var weightText = ""
    @State private var date = Date()
    @State private var note = ""
    @FocusState private var isWeightFieldFocused: Bool

    private var weightValue: Double? {
        Double(weightText)
    }

    private var isValid: Bool {
        guard let weight = weightValue else { return false }
        return weight > 0 && weight < 500
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    weightInputSection
                    dateSection
                    noteSection
                    saveButton
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                        .foregroundStyle(Color.hubPrimary)
                }
            }
            .onAppear {
                // Pre-fill with the latest weight for quick editing
                if let latest = viewModel.latestWeight {
                    weightText = String(format: "%.1f", latest.weight)
                }
                isWeightFieldFocused = true
            }
        }
    }

    // MARK: - Weight Input

    private var weightInputSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Weight (kg)")

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0.0", text: $weightText)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .focused($isWeightFieldFocused)

                    Text("kg")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                        .shadow(
                            color: colorScheme == .dark
                                ? Color.black.opacity(0.3)
                                : Color.black.opacity(0.06),
                            radius: 8,
                            x: 0,
                            y: 2
                        )
                )

                // Quick adjust buttons
                HStack(spacing: 8) {
                    quickAdjustButton(delta: -0.5)
                    quickAdjustButton(delta: -0.1)
                    quickAdjustButton(delta: +0.1)
                    quickAdjustButton(delta: +0.5)
                }
            }
        }
    }

    private func quickAdjustButton(delta: Double) -> some View {
        Button {
            if let current = weightValue {
                weightText = String(format: "%.1f", current + delta)
            }
        } label: {
            Text(delta > 0 ? "+\(String(format: "%.1f", delta))" : String(format: "%.1f", delta))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.hubPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.hubPrimary.opacity(0.1))
                )
        }
    }

    // MARK: - Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Date")

            DatePicker(
                "",
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(.hubPrimary)
            .padding(HubLayout.cardInnerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Note (Optional)")
            HubTextField(placeholder: "e.g., Morning, post-workout...", text: $note)
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        HubButton(L10n.commonSave, icon: "checkmark") {
            guard let weight = weightValue else { return }
            viewModel.addWeight(
                weight: weight,
                date: date,
                note: note.isEmpty ? nil : note
            )
            dismiss()
        }
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.5)
    }
}

// MARK: - Preview

#Preview {
    WeightLogView(viewModel: HealthViewModel())
}
