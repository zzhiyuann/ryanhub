import SwiftUI

struct SpendingTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SpendingTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputAmount: Double = 0.0
    @State private var selectedCategory: SpendingCategory = .food
    @State private var selectedPaymentmethod: SpendingPaymentMethod = .cash
    @State private var inputMerchant: String = ""
    @State private var inputIsrecurring: Bool = false
    @State private var inputNote: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Spending Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SpendingTrackerEntry(amount: inputAmount, category: selectedCategory, paymentMethod: selectedPaymentmethod, merchant: inputMerchant, isRecurring: inputIsrecurring, note: inputNote)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Amount ($)") {
                    Stepper("\(inputAmount) amount ($)", value: $inputAmount, in: 0...9999)
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
                        ForEach(SpendingPaymentMethod.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Merchant / Description") {
                    HubTextField(placeholder: "Merchant / Description", text: $inputMerchant)
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
