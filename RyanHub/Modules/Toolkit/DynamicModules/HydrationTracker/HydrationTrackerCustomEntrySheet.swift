import SwiftUI

struct HydrationTrackerCustomEntrySheet: View {
    let viewModel: HydrationTrackerViewModel
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var amount: Int = 250
    @State private var selectedDrinkType: DrinkType = .water
    @State private var isSaving = false

    private let minAmount = 50
    private let maxAmount = 2000
    private let stepSize = 50

    private var fillProgress: Double {
        Double(amount - minAmount) / Double(maxAmount - minAmount)
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Hydration Tracker",
            icon: "plus.circle.fill",
            canSave: !isSaving
        ) {
            saveEntry()
        } content: {
            // Amount section with cup indicator
            EntryFormSection(title: "Amount") {
                VStack(spacing: HubLayout.sectionSpacing) {
                    // Cup fill indicator + amount display
                    HStack(spacing: HubLayout.sectionSpacing) {
                        // Cup fill indicator
                        cupIndicator
                            .frame(width: 60, height: 80)

                        // Amount display
                        VStack(spacing: 4) {
                            Text("\(amount)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("ml")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, HubLayout.itemSpacing)

                    // Stepper
                    Stepper(
                        "Amount: \(amount) ml",
                        value: $amount,
                        in: minAmount...maxAmount,
                        step: stepSize
                    )
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
            }

            // Drink type section
            EntryFormSection(title: "Drink Type") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: HubLayout.itemSpacing), count: 5),
                    spacing: HubLayout.itemSpacing
                ) {
                    ForEach(DrinkType.allCases) { type in
                        drinkTypeButton(type)
                    }
                }
            }

            // Log button
            Button {
                saveEntry()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "drop.fill")
                        Text("Log Drink")
                            .font(.hubBody)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: HubLayout.buttonHeight)
                .background(Color.hubPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius))
            }
            .disabled(isSaving)
            .padding(.top, HubLayout.itemSpacing)
        }
    }

    // MARK: - Cup Indicator

    private var cupIndicator: some View {
        GeometryReader { geo in
            let cupWidth = geo.size.width
            let cupHeight = geo.size.height
            let wallThickness: CGFloat = 3
            let cornerRadius: CGFloat = 6
            let fillHeight = (cupHeight - wallThickness * 2) * fillProgress

            ZStack(alignment: .bottom) {
                // Cup outline
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3), lineWidth: wallThickness)
                    .frame(width: cupWidth, height: cupHeight)

                // Fill
                RoundedRectangle(cornerRadius: max(0, cornerRadius - wallThickness))
                    .fill(selectedDrinkType.fillColor.opacity(0.6))
                    .frame(
                        width: cupWidth - wallThickness * 2,
                        height: max(0, fillHeight)
                    )
                    .padding(.bottom, wallThickness)
                    .animation(.easeInOut(duration: 0.3), value: amount)
                    .animation(.easeInOut(duration: 0.3), value: selectedDrinkType)
            }
        }
    }

    // MARK: - Drink Type Button

    private func drinkTypeButton(_ type: DrinkType) -> some View {
        let isSelected = selectedDrinkType == type
        return Button {
            selectedDrinkType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))

                Text(type.displayName)
                    .font(.hubCaption)
                    .foregroundStyle(
                        isSelected
                            ? AdaptiveColors.textPrimary(for: colorScheme)
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.hubPrimary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.hubPrimary : Color.clear, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Save

    private func saveEntry() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await viewModel.quickAddAmount(amount, drinkType: selectedDrinkType)
            onSave?()
            dismiss()
        }
    }
}

// MARK: - DrinkType Fill Color

private extension DrinkType {
    var fillColor: Color {
        switch self {
        case .water: return .blue
        case .coffee: return .brown
        case .tea: return .green
        case .juice: return .orange
        case .other: return .purple
        }
    }
}