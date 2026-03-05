import SwiftUI

struct SpendingTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SpendingTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputAmount: Double = 0
    @State private var selectedCategory: SpendingCategory = .food
    @State private var selectedPaymentmethod: PaymentMethod = .cash
    @State private var inputIsrecurring: Bool = false
    @State private var inputNote: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Spending Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SpendingTrackerEntry(amount: inputAmount, category: selectedCategory, paymentMethod: selectedPaymentmethod, isRecurring: inputIsrecurring, note: inputNote)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Amount") {
                    TextField("Amount", value: $inputAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SpendingCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Payment Method") {
                    Picker("Payment Method", selection: $selectedPaymentmethod) {
                        ForEach(PaymentMethod.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Recurring Expense") {
                    Toggle("Recurring Expense", isOn: $inputIsrecurring)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Note") {
                    HubTextField(placeholder: "Note", text: $inputNote)
                }
        }
    }
}
