import SwiftUI

struct SpendingTrackerExpenseEntrySheet: View {

    let viewModel: SpendingTrackerViewModel
    var onSave: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var amountFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: HubLayout.itemSpacing), count: 3)

    private var canSave: Bool {
        guard let amount = Double(viewModel.entryAmount), amount > 0 else { return false }
        return true
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Expense",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                Task {
                    await viewModel.saveEntryFromSheet()
                    onSave?()
                }
            }
        ) {
            // MARK: - Amount

            EntryFormSection(title: "Amount") {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    TextField("0.00", text: Binding(
                        get: { viewModel.entryAmount },
                        set: { viewModel.entryAmount = $0 }
                    ))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .minimumScaleFactor(0.6)
                }
                .padding(.vertical, HubLayout.itemSpacing)
            }

            // MARK: - Category

            EntryFormSection(title: "Category") {
                LazyVGrid(columns: columns, spacing: HubLayout.itemSpacing) {
                    ForEach(SpendingCategory.allCases) { category in
                        let isSelected = viewModel.entryCategory == category

                        Button {
                            viewModel.entryCategory = category
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.title2)

                                Text(category.displayName)
                                    .font(.hubCaption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .fill(isSelected
                                          ? Color.hubPrimary.opacity(0.15)
                                          : AdaptiveColors.surface(for: colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .stroke(isSelected ? Color.hubPrimary : Color.clear, lineWidth: 2)
                            )
                            .foregroundStyle(isSelected
                                             ? Color.hubPrimary
                                             : AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // MARK: - Note

            EntryFormSection(title: "Note (Optional)") {
                HubTextField(
                    placeholder: "What was this for?",
                    text: Binding(
                        get: { viewModel.entryNote },
                        set: { viewModel.entryNote = $0 }
                    )
                )
            }
        }
        .onAppear {
            amountFocused = true
        }
    }
}