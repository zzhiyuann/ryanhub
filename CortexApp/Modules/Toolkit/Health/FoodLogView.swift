import SwiftUI

// MARK: - Food Log View

/// Sheet for logging a new food/meal entry.
struct FoodLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: HealthViewModel

    @State private var mealType: MealType = .lunch
    @State private var foodDescription = ""
    @State private var caloriesText = ""
    @State private var date = Date()
    @FocusState private var isDescriptionFocused: Bool

    private var isValid: Bool {
        !foodDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var caloriesValue: Int? {
        guard !caloriesText.isEmpty else { return nil }
        return Int(caloriesText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CortexLayout.sectionSpacing) {
                    mealTypeSection
                    descriptionSection
                    caloriesSection
                    dateSection
                    saveButton
                }
                .padding(CortexLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                        .foregroundStyle(Color.cortexPrimary)
                }
            }
            .onAppear {
                // Auto-select meal type based on time of day
                mealType = suggestedMealType()
                isDescriptionFocused = true
            }
        }
    }

    // MARK: - Meal Type Selection

    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "Meal Type")

            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    mealTypeButton(type)
                }
            }
        }
    }

    private func mealTypeButton(_ type: MealType) -> some View {
        let isSelected = mealType == type

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mealType = type
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .medium))

                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : AdaptiveColors.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: CortexLayout.buttonCornerRadius)
                    .fill(isSelected
                        ? Color.cortexPrimary
                        : AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(isSelected ? 0 : 0.3)
                            : Color.black.opacity(isSelected ? 0 : 0.06),
                        radius: isSelected ? 0 : 8,
                        x: 0,
                        y: isSelected ? 0 : 2
                    )
            )
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "What did you eat?")
            CortexTextField(placeholder: "e.g., Grilled chicken salad", text: $foodDescription)
                .focused($isDescriptionFocused)
        }
    }

    // MARK: - Calories

    private var caloriesSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "Estimated Calories (Optional)")
            CortexTextField(placeholder: "e.g., 450", text: $caloriesText)
                .keyboardType(.numberPad)
        }
    }

    // MARK: - Date & Time

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: "Date & Time")

            DatePicker(
                "",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(.cortexPrimary)
            .padding(CortexLayout.cardInnerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CortexLayout.cardCornerRadius)
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

    // MARK: - Save

    private var saveButton: some View {
        CortexButton(L10n.commonSave, icon: "checkmark") {
            viewModel.addFood(
                mealType: mealType,
                description: foodDescription.trimmingCharacters(in: .whitespaces),
                calories: caloriesValue,
                date: date
            )
            dismiss()
        }
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.5)
    }

    // MARK: - Helpers

    /// Suggest a meal type based on the current hour.
    private func suggestedMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<14: return .lunch
        case 14..<17: return .snack
        default: return .dinner
        }
    }
}

// MARK: - Preview

#Preview {
    FoodLogView(viewModel: HealthViewModel())
}
