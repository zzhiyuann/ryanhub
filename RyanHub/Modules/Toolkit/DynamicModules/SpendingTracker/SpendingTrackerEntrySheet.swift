import SwiftUI

struct SpendingTrackerEntrySheet: View {
    let viewModel: SpendingTrackerViewModel
    var onSave: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    @State private var amountText: String = ""
    @State private var category: SpendingCategory = .other
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var isRecurring: Bool = false
    @State private var note: String = ""
    @State private var entryDate: Date = Date()

    private var amount: Double {
        Double(amountText) ?? 0.0
    }

    private var canSave: Bool {
        amount > 0
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Spending Tracker",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: saveEntry
        ) {
            EntryFormSection(title: "Amount") {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .padding(.vertical, 4)
            }

            EntryFormSection(title: "Category") {
                Picker("Category", selection: $category) {
                    ForEach(SpendingCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon)
                            .tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.hubPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            EntryFormSection(title: "Payment Method") {
                Picker("Payment Method", selection: $paymentMethod) {
                    ForEach(PaymentMethod.allCases) { method in
                        Label(method.displayName, systemImage: method.icon)
                            .tag(method)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.hubPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            EntryFormSection(title: "Date") {
                DatePicker(
                    "",
                    selection: $entryDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .tint(Color.hubPrimary)
            }

            EntryFormSection(title: "Options") {
                Toggle("Recurring expense", isOn: $isRecurring)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .tint(Color.hubPrimary)
            }

            EntryFormSection(title: "Note") {
                TextField("Optional note…", text: $note)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    private func saveEntry() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let entry = SpendingTrackerEntry(
            id: UUID().uuidString,
            date: formatter.string(from: entryDate),
            amount: amount,
            category: category,
            paymentMethod: paymentMethod,
            isRecurring: isRecurring,
            note: note
        )

        Task { await viewModel.addEntry(entry) }
        onSave?()
    }
}