import SwiftUI

struct SubscriptionTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SubscriptionTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputName: String = ""
    @State private var inputAmount: Double = 0
    @State private var selectedCategory: SubscriptionCategory = .entertainment
    @State private var selectedBillingcycle: BillingCycle = .weekly
    @State private var inputRenewalday: Int = 1
    @State private var inputIsactive: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Subscription Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = SubscriptionTrackerEntry(name: inputName, amount: inputAmount, category: selectedCategory, billingCycle: selectedBillingcycle, renewalDay: inputRenewalday, isActive: inputIsactive, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Subscription Name") {
                    HubTextField(placeholder: "Subscription Name", text: $inputName)
                }

                EntryFormSection(title: "Amount") {
                    TextField("Amount", value: $inputAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SubscriptionCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Billing Cycle") {
                    Picker("Billing Cycle", selection: $selectedBillingcycle) {
                        ForEach(BillingCycle.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Renewal Day of Month") {
                    Stepper("\(inputRenewalday) renewal day of month", value: $inputRenewalday, in: 0...9999)
                }

                EntryFormSection(title: "Active") {
                    Toggle("Active", isOn: $inputIsactive)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
