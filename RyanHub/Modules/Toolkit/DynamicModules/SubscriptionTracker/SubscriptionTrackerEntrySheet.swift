import SwiftUI

struct SubscriptionTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SubscriptionTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputName: String = ""
    @State private var inputAmount: Double = 0.0
    @State private var selectedBillingcycle: BillingCycle = .weekly
    @State private var selectedCategory: SubscriptionCategory = .streaming
    @State private var inputNextrenewaldate: Date = Date()
    @State private var inputIsactive: Bool = false
    @State private var selectedPaymentmethod: PaymentMethod = .creditCard
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Subscription Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SubscriptionTrackerEntry(name: inputName, amount: inputAmount, billingCycle: selectedBillingcycle, category: selectedCategory, nextRenewalDate: inputNextrenewaldate, isActive: inputIsactive, paymentMethod: selectedPaymentmethod, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Subscription Name") {
                    HubTextField(placeholder: "Subscription Name", text: $inputName)
                }

                EntryFormSection(title: "Amount per Cycle") {
                    Stepper("\(inputAmount) amount per cycle", value: $inputAmount, in: 0...9999)
                }

                EntryFormSection(title: "Billing Cycle") {
                    Picker("Billing Cycle", selection: $selectedBillingcycle) {
                        ForEach(BillingCycle.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SubscriptionCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Next Renewal Date") {
                    DatePicker("Next Renewal Date", selection: $inputNextrenewaldate, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Active") {
                    Toggle("Active", isOn: $inputIsactive)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Payment Method") {
                    Picker("Payment Method", selection: $selectedPaymentmethod) {
                        ForEach(PaymentMethod.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
