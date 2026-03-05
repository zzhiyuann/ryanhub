import SwiftUI

struct ExpenseTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ExpenseTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputAmount: Double = 0
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var selectedPaymentmethod: PaymentMethod = .cash
    @State private var inputMerchant: String = ""
    @State private var inputNote: String = ""
    @State private var inputIsrecurring: Bool = false

    var body: some View {
        QuickEntrySheet(
            title: "Add Expense Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = ExpenseTrackerEntry(amount: inputAmount, category: selectedCategory, paymentMethod: selectedPaymentmethod, merchant: inputMerchant, note: inputNote, isRecurring: inputIsrecurring)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Amount ($)") {
                    TextField("0.00", value: $inputAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.hubPrimary)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { item in
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

                EntryFormSection(title: "Merchant") {
                    HubTextField(placeholder: "Merchant", text: $inputMerchant)
                }

                EntryFormSection(title: "Note") {
                    HubTextField(placeholder: "Note", text: $inputNote)
                }

                EntryFormSection(title: "Recurring Expense") {
                    Toggle("Recurring Expense", isOn: $inputIsrecurring)
                        .tint(Color.hubPrimary)
                }
        }
    }
}
